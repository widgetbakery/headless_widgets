import 'package:flutter/widgets.dart';
import 'package:headless/src/util.dart';

enum PopoverEdge {
  top,
  bottom,
  left,
  right,
}

/// Describes the attachment of the popover relative to the anchor.
class PopoverAttachment {
  const PopoverAttachment({
    required this.anchor,
    required this.popover,
  });

  /// Determines position of the anchor point relative to the anchor widget.
  final Alignment anchor;

  /// Determines position of the popover relative to the popover widget.
  final Alignment popover;

  /// Returns the edge of popover containing the popover call-out, if any.
  /// This is determined from the relative position of the anchor and popover.
  PopoverEdge? getCalloutEdge() {
    if (anchor.y == 1.0 && popover.y == -1.0) {
      return PopoverEdge.top;
    } else if (anchor.y == -1.0 && popover.y == 1.0) {
      return PopoverEdge.bottom;
    } else if (anchor.x == 1.0 && popover.x == -1.0) {
      return PopoverEdge.left;
    } else if (anchor.x == -1.0 && popover.x == 1.0) {
      return PopoverEdge.right;
    } else {
      return null;
    }
  }

  /// Returns the target position of popover with specified [popoverSize] and [distance] between
  /// the popover and anchor.
  /// The distance will only be applied if popover does not overlap with the anchor.
  Offset getPopoverOffset(Rect anchorRect, Size popoverSize, double distance) {
    final anchorPoint = _getPointInRect(anchor, anchorRect);
    final popoverPoint = _getPointInRect(popover, Offset.zero & popoverSize);
    var offset = anchorPoint - popoverPoint;

    final popoverRect = offset & popoverSize;
    if (popoverRect.top >= anchorRect.bottom - kEpsilon) {
      offset = offset.translate(0, distance);
    } else if (popoverRect.bottom <= anchorRect.top + kEpsilon) {
      offset = offset.translate(0, -distance);
    } else if (popoverRect.left >= anchorRect.right - kEpsilon) {
      offset = offset.translate(distance, 0);
    } else if (popoverRect.right <= anchorRect.left + kEpsilon) {
      offset = offset.translate(-distance, 0);
    }

    return offset;
  }

  Offset _getPointInRect(Alignment alignment, Rect rect) {
    return Offset(
      rect.left + rect.width * alignment.percentX,
      rect.top + rect.height * alignment.percentY,
    );
  }
}

/// Describes actual geometry of popover after a successful layout pass.
class PopoverGeometry {
  const PopoverGeometry({
    required this.attachment,
    required this.requestedDistance,
    required this.anchor,
    required this.popover,
    required this.popoverWidgetInsets,
    required this.calloutSize,
  });

  /// Popover attachment used to calculate initial position.
  ///
  /// [anchor] and [popover] coordinates are relative to the top left corner
  /// of the popover widget.
  final PopoverAttachment attachment;

  /// Requested distance between popover and anchor. Note that the actual
  /// distance may be smaller (or even negative) the popover position had to
  /// be adjusted to fit within the bounds.
  final double requestedDistance;

  /// Anchor rectangle. The coordinate system starts at top left corner
  /// of the popover widget.
  final Rect anchor;

  /// Popover rectangle. This demarcates the visible (unclipped) area of the
  /// popover widget. The origin of coordinate system is the top left corner
  /// of the popover widget.
  final Rect popover;

  /// Inflating [popover] by this amount will give the actual widget size.
  final EdgeInsets popoverWidgetInsets;

  /// The height of call-out.
  final double calloutSize;

  @override
  bool operator ==(Object other) {
    // Compare geometry with some tolerance to avoid needlessly triggering
    // reclip and repaint.
    return other is PopoverGeometry &&
        rectsEqual(anchor, other.anchor) &&
        rectsEqual(popover, other.popover) &&
        popoverWidgetInsets == other.popoverWidgetInsets &&
        calloutSize == other.calloutSize;
  }

  @override
  int get hashCode => Object.hash(
        anchor,
        popover,
        popoverWidgetInsets,
        calloutSize,
      );

  Alignment getAlignment() {
    final alignX = anchor.size.width >= popover.width
        ? 0.5
        : (anchor.center.dx - popover.left) / popover.width;
    final alignY = anchor.size.height >= popover.height
        ? 0.5
        : (anchor.center.dy - popover.top) / popover.height;
    final alignment = Alignment(
      (alignX.clamp(0.0, 1.0) - 0.5) * 2.0,
      (alignY.clamp(0.0, 1.0) - 0.5) * 2.0,
    );
    return alignment;
  }
}

extension AlignmentPercentExt on Alignment {
  double get percentX => (x + 1.0) / 2.0;
  double get percentY => (y + 1.0) / 2.0;
}
