import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Drop-in replacement for [MouseRegion] that that only reacts to hover events,
/// ignoring mouse dragging events. If mouse is pressed while in hover region,
/// hover events will stop until mouse is released and when mouse cursor leaves
/// the region while button is pressed, the [onExit] call will be delayed until
/// mouse button is released.
///
/// This matches macOS and Gtk+ behavior where hover on inactive elements
/// is not shown while mouse button is pressed. Hover is reported the moment
/// user releases the mouse over [HoverRegion].
///
/// Note that this is slightly different than Windows behavior, where to prevent
/// hover while dragging there must be a window that has captured the mouse. This
/// difference does not seem significant enough to warrant introducing additional
/// complexity.
///
/// This widget also supports delaying hover events while scrolling,
/// which matches native behavior and makes the application feel less busy.
class HoverRegion extends StatefulWidget {
  const HoverRegion({
    super.key,
    this.onEnter,
    this.onExit,
    this.onHover,
    this.cursor = MouseCursor.defer,
    this.delayEventsWhenScrolling = true,
    this.opaque = true,
    this.hitTestBehavior,
    required this.child,
  });

  /// Called when a pointer has entered the region, but only if the mouse
  /// button is not pressed.
  final PointerEnterEventListener? onEnter;

  /// Called when a pointer has exited the region. Only called if onEnter
  /// was called first.
  final PointerExitEventListener? onExit;

  /// Called when a pointer has moved within the region.
  final PointerHoverEventListener? onHover;

  /// The mouse cursor for mouse pointers that are hovering over the region.
  ///
  /// When a mouse enters the region, its cursor will be changed to the [cursor].
  /// When the mouse leaves the region, the cursor will be decided by the region
  /// found at the new location.
  ///
  /// The [cursor] defaults to [MouseCursor.defer], deferring the choice of
  /// cursor to the next region behind it in hit-test order.
  final MouseCursor cursor;

  /// If true, hover events are delayed while scrolling. This matches native
  /// behavior and makes the application feel less busy.
  final bool delayEventsWhenScrolling;

  /// Whether this widget should prevent other [MouseRegion]s visually behind it
  /// from detecting the pointer.
  ///
  /// This changes the list of regions that a pointer hovers, thus affecting how
  /// their [onHover], [onEnter], [onExit], and [cursor] behave.
  ///
  /// If [opaque] is true, this widget will absorb the mouse pointer and
  /// prevent this widget's siblings (or any other widgets that are not
  /// ancestors or descendants of this widget) from detecting the mouse
  /// pointer even when the pointer is within their areas.
  ///
  /// If [opaque] is false, this object will not affect how [MouseRegion]s
  /// behind it behave, which will detect the mouse pointer as long as the
  /// pointer is within their areas.
  ///
  /// This defaults to true.
  final bool opaque;

  /// How to behave during hit testing.
  ///
  /// This defaults to [HitTestBehavior.opaque] if null.
  final HitTestBehavior? hitTestBehavior;

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget child;

  @override
  State<StatefulWidget> createState() => _HoverRegionState();
}

class _HoverRegionState extends State<HoverRegion> {
  PointerEnterEvent? _pendingEnter;
  PointerHoverEvent? _pendingHover;
  PointerExitEvent? _pendingExit;
  int? _pendingExitPointer;
  int? _ignoredEnterPointer;

  bool _scrolling = false;

  ScrollPosition? _lastScrollPosition;
  Timer? _scrollResetTimer;

  bool _inside = false;

  void _updateScrolling(bool scrolling) {
    if (_scrolling != scrolling) {
      _scrolling = scrolling;
      _flush();
    }
  }

  bool get _preventNotifications => _scrolling;

  void _flush() {
    if (_pendingEnter != null && !_preventNotifications) {
      widget.onEnter?.call(_pendingEnter!);
      _inside = true;
      if (_pendingHover != null) {
        widget.onHover?.call(_pendingHover!);
      }
      _pendingEnter = null;
      _pendingHover = null;
    }
    // Refresh mouse cursor
    setState(() {});
  }

  void _resetScrollPosition() {
    final position = _lastScrollPosition;
    if (position != null) {
      position.isScrollingNotifier.removeListener(_scrollingDidChange);
      position.removeListener(_scrollingDidChange);
      _lastScrollPosition = null;
    }
    _scrollResetTimer?.cancel();
    _scrollResetTimer = null;
  }

  void _scrollingDidChange() {
    // Schedule at the end of frame because this might be called from
    // ScrollPosition.applyNewDimensions, which is invoked during layout.
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (!mounted) {
        return;
      }
      // macOS ends isScrolling when when lifting fingers from touchpad, which is
      // nice, on other platforms we rely on a timeout.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
        _updateScrolling(_lastScrollPosition!.isScrollingNotifier.value);
      } else {
        _updateScrolling(true);
      }
      _scrollResetTimer?.cancel();
      if (_scrolling) {
        _scrollResetTimer = Timer(const Duration(milliseconds: 100), () {
          _scrollResetTimer = null;
          _updateScrolling(false);
        });
      } else {
        _scrollResetTimer = null;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scrollable = widget.delayEventsWhenScrolling ? Scrollable.maybeOf(context) : null;
    _resetScrollPosition();
    if (scrollable != null) {
      _lastScrollPosition = scrollable.position;
      _lastScrollPosition!.isScrollingNotifier.addListener(_scrollingDidChange);
      _lastScrollPosition!.addListener(_scrollingDidChange);
    }
    if (_lastScrollPosition == null) {
      _scrolling = false;
    }
  }

  static bool? _runningInTester;

  // Flutter tester does not synthesize hover events on mouse up,
  // unlike native platforms.
  static bool _needSynthetizeHoverOnUp() {
    if (kIsWeb) {
      _runningInTester = false;
    } else {
      _runningInTester ??= Platform.environment.containsKey('FLUTTER_TEST');
    }
    return _runningInTester!;
  }

  void _onGlobalRoute(PointerEvent event) {
    if (event is PointerUpEvent) {
      if (event.pointer == _ignoredEnterPointer) {
        _ignoredEnterPointer = null;
        if (_needSynthetizeHoverOnUp()) {
          _onHover(PointerHoverEvent(
            viewId: event.viewId,
            timeStamp: event.timeStamp,
            kind: event.kind,
            pointer: 0,
            device: event.device,
            position: event.position,
            delta: event.delta,
            buttons: event.buttons,
            obscured: event.obscured,
            pressureMin: event.pressureMin,
            pressureMax: event.pressureMax,
            distance: event.distance,
            distanceMax: event.distanceMax,
            size: event.size,
            radiusMajor: event.radiusMajor,
            radiusMinor: event.radiusMinor,
            radiusMin: event.radiusMin,
            radiusMax: event.radiusMax,
            orientation: event.orientation,
            tilt: event.tilt,
            synthesized: event.synthesized,
            embedderId: event.embedderId,
          ));
        }
      }
      if (event.pointer == _pendingExitPointer) {
        assert(_pendingExit != null);
        assert(_inside);
        widget.onExit?.call(_pendingExit!);
        _inside = false;
        _pendingExitPointer = null;
        _pendingExit = null;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onGlobalRoute);
  }

  @override
  void dispose() {
    super.dispose();
    _resetScrollPosition();
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onGlobalRoute);
  }

  // Workaround for iOS with UIApplicationSupportsIndirectInputEvents set to true.
  // This seems to be sending nested PointerEnterEvents and PointerExitEvents when
  // pressing touch-pad.
  int _depth = 0;

  void _onEnter(PointerEnterEvent event) {
    ++_depth;
    if (_depth > 1) {
      return;
    }

    if (_pendingExitPointer == event.pointer) {
      _pendingExitPointer = null;
      _pendingExit = null;
    }
    if (!_inside && event.down) {
      _ignoredEnterPointer = event.pointer;
    } else if (!_inside) {
      if (_preventNotifications) {
        _pendingEnter = event;
      } else {
        _inside = true;
        widget.onEnter?.call(event);
      }
    }
  }

  void _onHover(PointerHoverEvent event) {
    if (_preventNotifications) {
      _pendingHover = event;
    } else {
      if (!_inside) {
        _inside = true;
        widget.onEnter?.call(PointerEnterEvent(
          viewId: event.viewId,
          timeStamp: event.timeStamp,
          pointer: event.pointer,
          kind: event.kind,
          device: event.device,
          position: event.position,
          delta: event.delta,
          buttons: event.buttons,
          obscured: event.obscured,
          pressureMin: event.pressureMin,
          pressureMax: event.pressureMax,
          distance: event.distance,
          distanceMax: event.distanceMax,
          size: event.size,
          radiusMajor: event.radiusMajor,
          radiusMinor: event.radiusMinor,
          radiusMin: event.radiusMin,
          radiusMax: event.radiusMax,
          orientation: event.orientation,
          tilt: event.tilt,
          down: false,
          synthesized: event.synthesized,
          embedderId: event.embedderId,
        ));
      }
      widget.onHover?.call(event);
    }
  }

  void _onExit(PointerExitEvent event) {
    if (_ignoredEnterPointer == event.pointer) {
      _ignoredEnterPointer = null;
    }

    --_depth;
    if (_depth > 0) {
      return;
    }

    if (_inside) {
      if (event.down) {
        _pendingExitPointer = event.pointer;
        _pendingExit = event;
      } else {
        _inside = false;
        widget.onExit?.call(event);
      }
    }
    _pendingEnter = null;
    _pendingHover = null;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: _onEnter,
      onExit: _onExit,
      onHover: _onHover,
      cursor: _preventNotifications ? MouseCursor.defer : widget.cursor,
      opaque: widget.opaque,
      child: widget.child,
    );
  }
}
