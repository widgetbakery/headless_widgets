import 'dart:ui';
import 'dart:math' as math;

import 'package:cupertino_rrect/cupertino_rrect.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';
import 'package:headless/headless.dart';

class SamplePopoverDelegate extends BasePopoverDelegate {
  SamplePopoverDelegate({
    required super.attachments,
  }) : super(
          calloutSize: 10,
          popoverDistance: 12,
          calloutAnimationDuration: const Duration(milliseconds: 150),
        );

  @override
  EdgeInsets getScreenInsets(EdgeInsets safeAreaInsets) {
    // Enforce minimum insets
    const min = EdgeInsets.all(20);
    return EdgeInsets.fromLTRB(
      math.max(min.left, safeAreaInsets.left),
      math.max(min.top, safeAreaInsets.top),
      math.max(min.right, safeAreaInsets.right),
      math.max(min.bottom, safeAreaInsets.bottom),
    );
  }

  @override
  Widget buildPopover(
    BuildContext context,
    child,
    Animation<double> animation,
    ValueNotifier<PopoverGeometry?> geometry,
    double Function(bool calloutVisible) calloutHeightFactor,
  ) {
    // Semi-transparent blur only works when there is nothing else in the opacity
    // layer (hence splitting the border and backdrop into separate layers) and
    // it doesn't work at all on web, in which case we animate sigma instead.

    final border = IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _PopoverPainter(
            geometry: geometry,
            getCalloutHeightFactor: calloutHeightFactor,
          ),
        ),
      ),
    );
    Widget clipAndBlur(double blurFactor, Widget child) => ClipPath(
          clipBehavior: Clip.antiAlias,
          clipper: _PopoverClipper(
            geometry: geometry,
            getCalloutHeightFactor: calloutHeightFactor,
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10 * blurFactor, sigmaY: 10 * blurFactor),
            child: child,
          ),
        );

    final geom = geometry.value;
    if (geom == null || animation.status == AnimationStatus.completed) {
      return Stack(
        fit: StackFit.passthrough,
        children: [
          clipAndBlur(1.0, child),
          Positioned.fill(child: border),
        ],
      );
    }

    animation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutQuad,
      reverseCurve: Curves.easeInQuad,
    );

    final Widget mainWidget;

    if (kIsWeb) {
      // On web we can't animate backdrop opacity, so instead we
      // animate the blur sigma and opacity of child below.
      mainWidget = AnimatedBuilder(
        animation: animation,
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
        builder: (context, child) {
          var factor = animation.value;
          if (factor < 0.5) {
            factor = 0;
          } else {
            factor = (factor - 0.5) * 2;
          }
          // Reduce number of blur factors to reduce shader variants.
          factor = (factor * 10).roundToDouble() / 10.0;
          return clipAndBlur(factor, child!);
        },
      );
    } else {
      // For desktop we can animate the opacity on the backdrop filter.
      mainWidget = FadeTransition(
        opacity: animation,
        child: clipAndBlur(1.0, child),
      );
    }

    return ScaleTransition(
      alignment: geom.getAlignment(),
      scale: Tween<double>(
        begin: 0.4,
        end: 1.0,
      ).animate(animation),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          mainWidget,
          Positioned.fill(
            child: FadeTransition(
              opacity: animation,
              child: border,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget buildVeil(
    BuildContext context,
    Animation<double> animation,
    VoidCallback dismissPopover,
  ) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        dismissPopover();
      },
    );
  }
}

class _PopoverClipper extends CustomClipper<Path> {
  const _PopoverClipper({
    required this.geometry,
    required this.getCalloutHeightFactor,
  }) : super(reclip: geometry);

  final ValueListenable<PopoverGeometry?> geometry;
  final double Function(bool calloutVisible) getCalloutHeightFactor;

  @override
  Path getClip(Size size) {
    final geometry = this.geometry.value;
    if (geometry != null) {
      return _makePopoverPath(
        size,
        geometry,
        getCalloutHeightFactor,
      );
    } else {
      return Path();
    }
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    return true;
  }
}

class _PopoverPainter extends CustomPainter {
  _PopoverPainter({
    required this.geometry,
    required this.getCalloutHeightFactor,
  }) : super(repaint: geometry);

  final ValueListenable<PopoverGeometry?> geometry;
  final double Function(bool calloutVisible) getCalloutHeightFactor;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = this.geometry.value;
    if (geometry == null) {
      return;
    }
    final path = _makePopoverPath(
      size,
      geometry,
      getCalloutHeightFactor,
    );

    // BlurStyle.outer doesn't seem to work with HTML renderer
    // so we clip manually.
    if (getCurrentRenderer() == FlutterRenderer.html) {
      final clip = Path();
      clip.fillType = PathFillType.evenOdd;
      clip.addRect(const EdgeInsets.all(20).inflateRect(Offset.zero & size));
      clip.addPath(path, Offset.zero);
      canvas.save();
      canvas.clipPath(clip);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withOpacity(0.2)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 5),
    );

    if (getCurrentRenderer() == FlutterRenderer.html) {
      canvas.restore();
    }

    canvas.drawPath(
      path,
      Paint()
        ..strokeWidth = 1
        ..color = Colors.grey.shade400
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

extension on PopoverEdge {
  Edge get asCupertinoEdge {
    switch (this) {
      case PopoverEdge.top:
        return Edge.top;
      case PopoverEdge.bottom:
        return Edge.bottom;
      case PopoverEdge.left:
        return Edge.left;
      case PopoverEdge.right:
        return Edge.right;
    }
  }
}

Path _makePopoverPath(
  Size size,
  PopoverGeometry geometry,
  double Function(bool calloutVisible) getCalloutHeightFactor,
) {
  final rect = geometry.popover;
  final path = Path();
  path.addCupertinoRRect(
    RRect.fromRectAndRadius(rect, const Radius.circular(10)),
    lineCallback: (path, from, to, edge) {
      if (edge != geometry.attachment.getCalloutEdge()?.asCupertinoEdge) {
        path.lineTo(to.dx, to.dy);
        return;
      }
      // Attachment position of notch in main axis extent
      double attachmentPosition;
      double crossAxisDistance;
      double mainAxisPositionMin;
      double mainAxisPositionMax;
      double crossAxisPosition;
      final double calloutMainSizeHalf = geometry.calloutSize * 1.2;
      double calloutCrossAxisSize = geometry.calloutSize;
      double calloutCrossAxisSign;
      double mainAxisSign;

      if (edge.isHorizontal) {
        attachmentPosition =
            geometry.anchor.left + geometry.anchor.width * geometry.attachment.anchor.percentX;
        mainAxisPositionMin = math.min(from.dx, to.dx) + calloutMainSizeHalf;
        mainAxisPositionMax = math.max(from.dx, to.dx) - calloutMainSizeHalf;
      } else {
        attachmentPosition =
            geometry.anchor.top + geometry.anchor.height * geometry.attachment.anchor.percentY;
        mainAxisPositionMin = math.min(from.dy, to.dy) + calloutMainSizeHalf;
        mainAxisPositionMax = math.max(from.dy, to.dy) - calloutMainSizeHalf;
      }

      if (edge == Edge.top) {
        crossAxisDistance = rect.top - geometry.anchor.bottom;
        crossAxisPosition = rect.top;
        calloutCrossAxisSign = -1.0;
        mainAxisSign = 1.0;
      } else if (edge == Edge.bottom) {
        crossAxisDistance = geometry.anchor.top - rect.bottom;
        crossAxisPosition = rect.bottom;
        calloutCrossAxisSign = 1.0;
        mainAxisSign = -1.0;
      } else if (edge == Edge.left) {
        crossAxisDistance = rect.left - geometry.anchor.right;
        crossAxisPosition = rect.left;
        calloutCrossAxisSign = -1.0;
        mainAxisSign = -1.0;
      } else {
        crossAxisDistance = geometry.anchor.left - rect.right;
        crossAxisPosition = rect.right;
        calloutCrossAxisSign = 1.0;
        mainAxisSign = 1.0;
      }

      final bool calloutVisible = crossAxisDistance == geometry.requestedDistance &&
          mainAxisPositionMin <= attachmentPosition &&
          mainAxisPositionMax >= attachmentPosition;

      final heightFactor = getCalloutHeightFactor(calloutVisible);
      calloutCrossAxisSize *= heightFactor;

      if (calloutCrossAxisSize == 0) {
        path.lineTo(to.dx, to.dy);
        return;
      }

      attachmentPosition = attachmentPosition.clamp(mainAxisPositionMin, mainAxisPositionMax);

      final control1 = mainAxisSign * (calloutMainSizeHalf / 2.0);
      final control2 = mainAxisSign * (calloutMainSizeHalf / 3.0);

      final calloutMainAxisStart = attachmentPosition - mainAxisSign * calloutMainSizeHalf;
      final calloutMainAxisEnd = attachmentPosition + mainAxisSign * calloutMainSizeHalf;

      void lineTo(double x, double y) {
        if (edge.isHorizontal) {
          path.lineTo(x, y);
        } else {
          path.lineTo(y, x);
        }
      }

      void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) {
        if (edge.isHorizontal) {
          path.cubicTo(x1, y1, x2, y2, x3, y3);
        } else {
          path.cubicTo(y1, x1, y2, x2, y3, x3);
        }
      }

      lineTo(
        calloutMainAxisStart,
        crossAxisPosition,
      );
      cubicTo(
        calloutMainAxisStart + control1,
        crossAxisPosition,
        attachmentPosition - control2,
        crossAxisPosition + calloutCrossAxisSign * calloutCrossAxisSize,
        attachmentPosition,
        crossAxisPosition + calloutCrossAxisSign * calloutCrossAxisSize,
      );
      cubicTo(
        attachmentPosition + control2,
        crossAxisPosition + calloutCrossAxisSign * calloutCrossAxisSize,
        calloutMainAxisEnd - control1,
        crossAxisPosition,
        calloutMainAxisEnd,
        crossAxisPosition,
      );
      path.lineTo(to.dx, to.dy);
      return;
    },
  );

  return path;
}