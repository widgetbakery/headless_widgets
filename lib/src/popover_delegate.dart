import 'package:flutter/widgets.dart';

import 'popover.dart';
import 'popover_geometry.dart';

/// Convenience class implementing common functionality of [PopoverDelegate].
abstract class BasePopoverDelegate extends PopoverDelegate {
  BasePopoverDelegate({
    required this.attachments,
    required this.calloutAnimationDuration,
  });

  /// List of attachments to try in order. The attachment that fits best
  /// (needs least amount of correction) will be used through-out the life-time
  /// of the popover.
  final List<PopoverAttachment> attachments;

  /// Height of the popover call-out.
  double get calloutSize;

  /// Requested distance between the popover and anchor. This may not be honored
  /// if popover needs to be repositioned to fit on screen.
  double get popoverDistance;

  /// Returns the insets that used when positioning popover on screen.
  EdgeInsets getScreenInsets(EdgeInsets safeAreaInsets) {
    return safeAreaInsets;
  }

  /// Duration of animation for hiding / showing popover call-out.
  final Duration calloutAnimationDuration;

  /// Builds the scaffold widget containing the popover. The scaffold is responsible
  /// for animating the popover in and out, painting popover shadow and clipping
  /// the child.
  ///
  /// [animation] used to animate the popover in and out.
  ///
  /// [geometry] listenable with current popover geometry. Can be used to
  /// trigger recliping of the child.
  ///
  /// [calloutHeightFactor] Returns the height factor (0.0-1.0) to be applied
  /// to popover height. Used when animating the call-out in and out. The
  /// The [calloutVisible] parameter informs delegate whether the call-out is
  /// visible, which potentially triggers the call-out animation.
  Widget buildPopover(
    BuildContext context,
    Widget child,
    Animation<double> animation,
    ValueNotifier<PopoverGeometry?> geometry,
    double Function(bool calloutVisible) calloutHeightFactor,
  );

  @override
  Widget buildVeil(
    BuildContext context,
    Animation<double> animation,
    VoidCallback dismissPopover,
  );

  //
  // Implementation
  //

  @override
  @mustCallSuper
  Widget buildScaffold(
    BuildContext context,
    Widget child,
    Animation<double> animation,
  ) {
    final queryData = MediaQuery.of(context);
    return MediaQuery(
      data: queryData.copyWith(padding: EdgeInsets.all(calloutSize)),
      child: Builder(
        builder: (context) {
          return buildPopover(
            context,
            child,
            animation,
            _geometry,
            _getCallloutHeightFactor,
          );
        },
      ),
    );
  }

  @override
  @mustCallSuper
  void dispose() {
    _geometry.dispose();
    _calloutAnimation?.dispose();
    super.dispose();
  }

  late TickerProvider _tickerProvider;
  AnimationController? _calloutAnimation;

  double _getCallloutHeightFactor(bool visible) {
    if (_calloutAnimation == null) {
      _calloutAnimation = AnimationController(
        vsync: _tickerProvider,
        duration: calloutAnimationDuration,
      );
      _calloutAnimation!.addListener(() {
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          _geometry.notify();
        });
      });

      _calloutAnimation!.value = visible ? 1.0 : 0.0;
    } else {
      if (visible && _calloutAnimation!.status != AnimationStatus.forward) {
        _calloutAnimation!.forward();
      } else if (!visible && _calloutAnimation!.status != AnimationStatus.reverse) {
        _calloutAnimation!.reverse();
      }
    }
    return Curves.easeInCubic.transform(_calloutAnimation!.value);
  }

  @override
  void setTickerProvider(TickerProvider tickerProvider) {
    _tickerProvider = tickerProvider;
  }

  /// Attachment that needs least correction initially. This is preserved even
  /// if bounds or popover size change in order to prevent popover from jumping
  /// around too much.
  PopoverAttachment? _resolvedAttachment;

  /// Current calculated geometry.
  final _geometry = _GeometryNotifier(null);

  @override
  @mustCallSuper
  BoxConstraints computeConstraints(
    Rect bounds,
    EdgeInsets safeAreaInsets,
    Rect anchor,
  ) {
    final insets = getScreenInsets(safeAreaInsets);
    var adjustedBounds = insets.deflateRect(bounds);
    adjustedBounds = EdgeInsets.all(calloutSize).inflateRect(adjustedBounds);
    return BoxConstraints.loose(adjustedBounds.size);
  }

  @override
  @mustCallSuper
  Offset computePosition(
    Rect bounds,
    EdgeInsets safeAreaInsets,
    Rect anchor,
    Size popoverSize,
  ) {
    final insets = getScreenInsets(safeAreaInsets);
    final adjustedBounds = insets.deflateRect(bounds);

    final size = EdgeInsets.all(calloutSize).deflateSize(popoverSize);

    _resolvedAttachment ??= _bestMatchingAttachment(
      bounds: adjustedBounds,
      anchorRect: anchor,
      popoverSize: size,
      distance: popoverDistance,
      attachments: attachments,
    );

    var offset = _resolvedAttachment!.getPopoverOffset(
      anchor,
      size,
      popoverDistance,
    );

    offset += _fitRectInBounds(
      rect: offset & size,
      bounds: adjustedBounds,
    );

    final res = Offset(
      offset.dx - calloutSize,
      offset.dy - calloutSize,
    );

    final translate = -offset + Offset(calloutSize, calloutSize);

    _geometry.value = PopoverGeometry(
      attachment: _resolvedAttachment!,
      anchor: anchor.translate(translate.dx, translate.dy),
      popover: (offset & size).translate(translate.dx, translate.dy),
      popoverWidgetInsets: EdgeInsets.all(calloutSize),
      requestedDistance: popoverDistance,
      calloutSize: calloutSize,
    );

    return res;
  }
}

PopoverAttachment _bestMatchingAttachment({
  required Rect bounds,
  required Rect anchorRect,
  required Size popoverSize,
  required double distance,
  required List<PopoverAttachment> attachments,
}) {
  if (attachments.isEmpty) {
    throw StateError('No attachments provided');
  }
  Offset? bestCorrection;
  PopoverAttachment? bestAttachment;

  for (final attachment in attachments) {
    final offset = attachment.getPopoverOffset(anchorRect, popoverSize, distance);
    final popoverRect = offset & popoverSize;
    final correction = _fitRectInBounds(bounds: bounds, rect: popoverRect);
    if (correction == Offset.zero) {
      return attachment;
    }
    if (bestCorrection == null || bestCorrection.distanceSquared > correction.distanceSquared) {
      bestCorrection = correction;
      bestAttachment = attachment;
    }
  }
  return bestAttachment!;
}

Offset _fitRectInBounds({required Rect bounds, required Rect rect}) {
  final dx1 = rect.left < bounds.left ? bounds.left - rect.left : 0.0;
  final dx2 = rect.right > bounds.right ? bounds.right - rect.right : 0.0;
  final dy1 = rect.top < bounds.top ? bounds.top - rect.top : 0.0;
  final dy2 = rect.bottom > bounds.bottom ? bounds.bottom - rect.bottom : 0.0;
  return Offset(dx1 + dx2, dy1 + dy2);
}

class _GeometryNotifier extends ValueNotifier<PopoverGeometry?> {
  _GeometryNotifier(super.value);

  void notify() {
    notifyListeners();
  }
}
