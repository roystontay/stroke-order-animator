import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:stroke_order_animator/src/brush.dart';
import 'package:stroke_order_animator/src/character_painter.dart';
import 'package:stroke_order_animator/src/stroke_order_animation_controller.dart';

/// A widget for displaying a stroke order diagram.
///
/// Requires a [StrokeOrderAnimationController] that controls the animation.
///
/// Tip: When using the animations in a [PageView] or [ListView], it is
/// recommended to use a unique key for every [StrokeOrderAnimator] and cancel
/// the animation when the selected page changes in order to avoid broken
/// animation behavior.

// Custom Gesture Recognizer
class CustomPanGestureRecognizer extends OneSequenceGestureRecognizer {
  CustomPanGestureRecognizer({super.debugOwner});

  Function(Offset)? onPanStart;
  Function(Offset)? onPanUpdate;
  Function()? onPanEnd;

  @override
  void addPointer(PointerEvent event) {
    startTrackingPointer(event.pointer);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      onPanUpdate?.call(event.localPosition);
    } else if (event is PointerDownEvent) {
      onPanStart?.call(event.localPosition);
    } else if (event is PointerUpEvent) {
      onPanEnd?.call();
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  String get debugDescription => 'customPan';

  @override
  void didStopTrackingLastPointer(int pointer) {}
}

class StrokeOrderAnimator extends StatefulWidget {
  const StrokeOrderAnimator(
    this._controller, {
    this.size = const Size(1024, 1024),
    super.key,
  });

  final StrokeOrderAnimationController _controller;
  final Size size;

  @override
  StrokeOrderAnimatorState createState() => StrokeOrderAnimatorState();
}

class StrokeOrderAnimatorState extends State<StrokeOrderAnimator> {
  final List<Offset> _currentUserStroke = <Offset>[];
  bool _userStrokeLeftCanvas = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget._controller;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) => RawGestureDetector(
        gestures: {
          CustomPanGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<CustomPanGestureRecognizer>(
            () => CustomPanGestureRecognizer(),
            (CustomPanGestureRecognizer instance) {
              instance.onPanUpdate = (details) {
                // User continues stroke
                if (_userStrokeLeftCanvas) {
                  return;
                }

                final RenderBox box = context.findRenderObject()! as RenderBox;
                final Offset point = box.globalToLocal(details);

                setState(() {
                  if (_pointIsOnCanvas(point, box)) {
                    _currentUserStroke.add(
                      // Normalize point to 1024x1024 coordinate system
                      Offset(point.dx / box.size.width,
                              point.dy / box.size.height) *
                          1024,
                    );
                  } else {
                    _userStrokeLeftCanvas = true;
                  }
                });
              };
              instance.onPanEnd = () {
                // User finished stroke
                controller.checkStroke(_currentUserStroke);
                setState(() {
                  _currentUserStroke.clear();
                  _userStrokeLeftCanvas = false;
                });
              };
            },
          ),
        },
        child: SizedBox(
          width: widget.size.width,
          height: widget.size.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: CharacterPainter(controller)),
              if (controller.showUserStroke)
                ..._paintCorrectUserStrokes(controller, widget.size),
              if (controller.isQuizzing && _currentUserStroke.isNotEmpty)
                _paintCurrentUserStroke(
                  _currentUserStroke,
                  controller,
                  widget.size,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _pointIsOnCanvas(Offset point, RenderBox box) {
  return point.dx >= 0 &&
      point.dx <= box.size.width &&
      point.dy >= 0 &&
      point.dy <= box.size.height;
}

List<CustomPaint> _paintCorrectUserStrokes(
  StrokeOrderAnimationController controller,
  Size size,
) {
  return controller.summary.correctStrokePaths
      .where((stroke) => stroke.isNotEmpty)
      .map(
        (stroke) => CustomPaint(
          painter: Brush(
            _scaleUserStroke(stroke, size),
            brushColor: controller.brushColor,
            brushWidth: controller.brushWidth,
          ),
        ),
      )
      .toList();
}

CustomPaint _paintCurrentUserStroke(
  List<Offset> stroke,
  StrokeOrderAnimationController controller,
  Size size,
) {
  return CustomPaint(
    painter: Brush(
      _scaleUserStroke(stroke, size),
      brushColor: controller.brushColor,
      brushWidth: controller.brushWidth,
    ),
  );
}

List<Offset> _scaleUserStroke(List<Offset> stroke, Size size) {
  return stroke
      .map((p) => Offset(p.dx * size.width, p.dy * size.height) / 1024)
      .toList();
}
