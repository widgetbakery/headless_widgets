import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class CaptureAwareMouseRegion extends StatefulWidget {
  const CaptureAwareMouseRegion({
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

  final PointerEnterEventListener? onEnter;
  final PointerExitEventListener? onExit;
  final PointerHoverEventListener? onHover;
  final MouseCursor cursor;
  final bool delayEventsWhenScrolling;
  final bool opaque;
  final HitTestBehavior? hitTestBehavior;
  final Widget child;

  @override
  State<StatefulWidget> createState() => _CaptureAwareMouseRegionState();
}

final _captureOwner = ValueNotifier<State?>(null);

mixin MouseCapture<T extends StatefulWidget> on State<T> {
  void captureMouse() {
    _captureOwner.value = this;
  }

  void releaseMouse() {
    if (_captureOwner.value == this) {
      _captureOwner.value = null;
    }
  }

  bool get hasMouseCapture => _captureOwner.value == this;

  @override
  void dispose() {
    super.dispose();
    releaseMouse();
  }
}

class _CaptureAwareMouseRegionState extends State<CaptureAwareMouseRegion> {
  PointerEnterEvent? _pendingEnter;
  PointerHoverEvent? _pendingHover;

  void _captureOwnerDidChange() {
    _cachedCaptureByAnotherSubtree = null;
    _update();
  }

  void _update() {
    if (_pendingEnter != null && !_shouldPreventNotifications()) {
      widget.onEnter?.call(_pendingEnter!);
      if (_pendingHover != null) {
        widget.onHover?.call(_pendingHover!);
      }
      _pendingEnter = null;
      _pendingHover = null;
      // Refresh mouse cursor
    }
    setState(() {});
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

  bool _scrolling = false;
  ScrollPosition? _lastScrollPosition;
  Timer? _scrollResetTimer;

  void _updateScrolling(bool scrolling) {
    if (_scrolling != scrolling) {
      _scrolling = scrolling;
      _update();
    }
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
  }

  @override
  void initState() {
    super.initState();
    _captureOwner.addListener(_captureOwnerDidChange);
  }

  @override
  void dispose() {
    super.dispose();
    _captureOwner.removeListener(_captureOwnerDidChange);
    _resetScrollPosition();
  }

  bool? _cachedCaptureByAnotherSubtree;

  bool _shouldPreventNotifications() {
    return _isMouseCapturedByAnotherSubtree() || _scrolling;
  }

  bool _isMouseCapturedByAnotherSubtree() {
    if (_cachedCaptureByAnotherSubtree != null) {
      return _cachedCaptureByAnotherSubtree!;
    }
    final currentOwner = _captureOwner.value;
    if (currentOwner == null) {
      return false;
    }
    bool inSubTree = false;
    // This element being above currentOwner.
    currentOwner.context.visitAncestorElements((ancestor) {
      if (ancestor == context) {
        inSubTree = true;
        return false;
      }
      return true;
    });
    if (!inSubTree) {
      // This element being below currentOwner.
      context.visitAncestorElements((element) {
        if (element == currentOwner.context) {
          inSubTree = true;
          return false;
        }
        return true;
      });
    }
    _cachedCaptureByAnotherSubtree = !inSubTree;
    return !inSubTree;
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
    if (_shouldPreventNotifications()) {
      _pendingEnter = event;
      return;
    }
    widget.onEnter?.call(event);
  }

  void _onHover(PointerHoverEvent event) {
    if (_shouldPreventNotifications()) {
      _pendingHover = event;
      return;
    }
    widget.onHover?.call(event);
  }

  void _onExit(PointerExitEvent event) {
    --_depth;
    if (_depth > 0) {
      return;
    }
    if (_pendingEnter == null) {
      widget.onExit?.call(event);
    }
    _pendingEnter = null;
    _pendingHover = null;
  }

  @override
  Widget build(BuildContext context) {
    final shouldPrevent = _shouldPreventNotifications();
    return MouseRegion(
      onEnter: _onEnter,
      onExit: _onExit,
      onHover: _onHover,
      cursor: shouldPrevent ? MouseCursor.defer : widget.cursor,
      opaque: widget.opaque,
      child: widget.child,
    );
  }
}
