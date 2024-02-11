import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class PopoverController {
  Future<void> showPopover(Widget popover) async {
    await __state?.showPopover(popover);
  }

  void hidePopover() {
    __state?.hidePopover();
  }

  set _state(_PopoverAnchorState? state) {
    if (__state != null && state != null && __state != state) {
      throw StateError('PopoverController is already attached to a state.');
    }
    __state = state;
  }

  _PopoverAnchorState? get _state => __state;
  _PopoverAnchorState? __state;
}

abstract class PopoverDelegate {
  /// Computes the constraints for the popover.
  ///
  /// - [bounds] is the entire area available for the popover.
  /// - [safeAreaInsets] is the area of bounds that is covered by system UI elements
  /// - [anchor] is the rectangle that the popover should be anchored to
  ///   represented in same coordinate space as [bounds].
  BoxConstraints computeConstraints(
    Rect bounds,
    EdgeInsets safeAreaInsets,
    Rect anchor,
  );

  /// Computes the position for the popover.
  ///
  /// - [bounds] is the entire area available for the popover.
  /// - [safeAreaInsets] is the area of bounds that is covered by system UI elements
  /// - [anchor] is the rectangle that the popover should be anchored to.
  /// - [popoverSize] is the size of the popover.
  Offset computePosition(
    Rect bounds,
    EdgeInsets safeAreaInsets,
    Rect anchor,
    Size popoverSize,
  );

  /// Builds the scaffold widget containing the popover. The scaffold is responsible
  /// for animating the popover in and out, painting popover shadow and clipping
  /// the child.
  ///
  /// Once the popover animation is complete the method will be called again with
  /// animation status set to [AnimationStatus.completed] in order for delegate
  /// to be able to remove unnecessary widgets from the tree.
  ///
  /// When showing popover this method will be called before [computePosition] and
  /// then also the next frame.
  Widget buildScaffold(
    BuildContext context,
    Widget child,
    Animation<double> animation,
  );

  Widget buildVeil(
    BuildContext context,
    Animation<double> animation,
    VoidCallback dismissPopover,
  );

  void setTickerProvider(TickerProvider tickerProvider) {}

  /// Called when the popover has been hidden and this delegate is no longer needed.
  void dispose() {}
}

class PopoverAnchor extends StatefulWidget {
  const PopoverAnchor({
    super.key,
    required this.controller,
    required this.child,
    required this.delegate,
    this.animationDuration = Duration.zero,
    this.animationReverseDuration,
  });

  final PopoverController controller;
  final Widget child;
  final PopoverDelegate Function() delegate;

  final Duration animationDuration;
  final Duration? animationReverseDuration;

  @override
  State<StatefulWidget> createState() => _PopoverAnchorState();
}

class _SizeMonitor extends SingleChildRenderObjectWidget {
  const _SizeMonitor({
    required Widget child,
    required this.onSizeChanged,
  }) : super(child: child);

  final ValueChanged<Size> onSizeChanged;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _SizeMonitorRenderBox(onSizeChanged);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _SizeMonitorRenderBox).onSizeChanged = onSizeChanged;
  }
}

class _SizeMonitorRenderBox extends RenderProxyBox {
  _SizeMonitorRenderBox(this.onSizeChanged);

  ValueChanged<Size> onSizeChanged;

  @override
  void performLayout() {
    super.performLayout();
    onSizeChanged(size);
  }
}

class _PopoverAnchorState extends State<PopoverAnchor>
    with TickerProviderStateMixin {
  final _overlayPortalController = OverlayPortalController();

  Widget _popoverChild = const SizedBox();
  final _focusScopeNode = FocusScopeNode(
    debugLabel: 'PopoverFocusScope',
  );
  Completer? _completer;
  Size _anchorSize = Size.zero;
  final _relayout = _SimpleNotifier();
  late final AnimationController _animation;

  // The layout callback on delegate has not been called yet.
  bool _pendingLayout = true;
  PopoverDelegate? _delegate;

  @override
  void initState() {
    super.initState();
    _focusScopeNode.addListener(() {
      if (_completer != null && !_focusScopeNode.hasFocus) {
        _completer!.complete();
      }
    });
    _addPersistentFrameCallback(_onFrame);
    _animation = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
      reverseDuration: widget.animationReverseDuration,
    );
    _animation.addStatusListener(_animationStatusChanged);
    widget.controller._state = this;
  }

  @override
  void didUpdateWidget(covariant PopoverAnchor oldWidget) {
    assert(oldWidget.controller._state == this);
    oldWidget.controller._state = null;
    widget.controller._state = this;
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _focusScopeNode.dispose();
    _relayout.dispose();
    _removePersistentFrameCallback(_onFrame);
    widget.controller._state = null;
    _completer?.complete();
    super.dispose();
  }

  void _onFrame(Duration _) {
    _relayout.notify();
  }

  void _onLayoutComplete() {
    if (_pendingLayout) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {});
      });
      _pendingLayout = false;
    }
  }

  final _childKey = GlobalKey();

  Widget _buildPopover(BuildContext context) {
    final child = _delegate!.buildScaffold(
      context,
      KeyedSubtree(key: _childKey, child: _popoverChild),
      _animation,
    );

    if (_pendingLayout) {
      return Visibility(
        visible: false,
        maintainSize: true,
        maintainState: true,
        maintainAnimation: true,
        child: child,
      );
    }
    return child;
  }

  Widget _buildChild(BuildContext context) {
    if (_delegate == null) {
      _delegate = widget.delegate();
      _delegate!.setTickerProvider(this);
    }
    return _CustomMultiChildLayout(
      delegate: _PopoverLayout(
        anchor: this.context,
        safeAreaInsets: MediaQuery.of(context).padding,
        anchorSize: () => _anchorSize,
        relayout: _relayout,
        delegate: _delegate!,
        onLayoutComplete: _onLayoutComplete,
      ),
      children: [
        LayoutId(
          id: _Slot.veil,
          child: _delegate!.buildVeil(
            context,
            _animation,
            () => _completer?.complete(),
          ),
        ),
        LayoutId(
          id: _Slot.popover,
          child: Actions(
            actions: {
              DismissIntent: CallbackAction(onInvoke: (_) {
                hidePopover();
                return null;
              }),
            },
            child: FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(
                requestFocusCallback: (node,
                    {alignment, alignmentPolicy, curve, duration}) {
                  // Buggy flutter will find scrollable in element tree that isn't part
                  // of the render tree :-/
                  node.requestFocus();
                },
              ),
              child: FocusScope(
                node: _focusScopeNode,
                child: Builder(builder: (context) {
                  return _buildPopover(context);
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _overlayPortalController,
      overlayChildBuilder: _buildChild,
      child: _SizeMonitor(
        onSizeChanged: (size) {
          _anchorSize = size;
        },
        child: widget.child,
      ),
    );
  }

  void _animationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      _overlayPortalController.hide();
      _pendingLayout = true;
      _delegate?.dispose();
      _delegate = null;
    } else {
      // Force rebuild - we'll want to remove the transition from the tree.
      setState(() {});
    }
  }

  Future<void> showPopover(Widget overlay) async {
    _pendingLayout = true;
    _popoverChild = overlay;
    _completer ??= Completer();
    _overlayPortalController.show();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _focusScopeNode.requestFocus();
    });
    _animation.forward();
    await _completer?.future;
    _completer = null;
    if (mounted) {
      // might have been disposed in the meanwhile
      _animation.reverse();
    }
  }

  void hidePopover() {
    _completer?.complete();
  }
}

enum _Slot {
  popover,
  veil,
}

class _PopoverLayout extends MultiChildLayoutDelegate {
  _PopoverLayout({
    required this.anchor,
    required this.safeAreaInsets,
    required this.anchorSize,
    required this.delegate,
    required this.onLayoutComplete,
    super.relayout,
  });

  final BuildContext anchor;
  final ValueGetter<Size> anchorSize;
  final EdgeInsets safeAreaInsets;
  final PopoverDelegate delegate;
  final VoidCallback onLayoutComplete;

  @override
  void performLayout(Size boundsSize) {
    if (hasChild(_Slot.popover)) {
      final bounds = Offset.zero & boundsSize;
      final renderObject = anchor.findRenderObject() as RenderBox;
      final anchorToWindow = renderObject.getTransformTo(null);
      final windowToUs = _RenderCustomMultiChildLayoutBox._currentLayout!
          .getTransformTo(null)
        ..invert();
      final anchorRect = Offset.zero & anchorSize();
      final transformed = MatrixUtils.transformRect(
        windowToUs,
        MatrixUtils.transformRect(anchorToWindow, anchorRect),
      );
      final constraints = delegate.computeConstraints(
        bounds,
        safeAreaInsets,
        transformed,
      );
      final size = layoutChild(_Slot.popover, constraints);

      final offset = delegate.computePosition(
        bounds,
        safeAreaInsets,
        transformed,
        size,
      );
      positionChild(_Slot.popover, offset);

      onLayoutComplete();
    }
    if (hasChild(_Slot.veil)) {
      layoutChild(_Slot.veil, BoxConstraints.loose(boundsSize));
      positionChild(_Slot.veil, Offset.zero);
    }
  }

  @override
  bool shouldRelayout(covariant MultiChildLayoutDelegate oldDelegate) {
    return false;
  }
}

class _SimpleNotifier extends ChangeNotifier {
  void notify() {
    notifyListeners();
  }
}

final _frameCallbacks = <FrameCallback>[];
bool _frameCallbacksScheduled = false;

void _addPersistentFrameCallback(FrameCallback callback) {
  if (!_frameCallbacksScheduled) {
    // Microtask otherwise FlutterTest fails with ConcurrentModificationError.
    Future.microtask(() {
      SchedulerBinding.instance.addPersistentFrameCallback((timestamp) {
        final callbacks = List.of(_frameCallbacks);
        for (final callback in callbacks) {
          callback(timestamp);
        }
      });
    });
    _frameCallbacksScheduled = true;
  }
  _frameCallbacks.add(callback);
}

void _removePersistentFrameCallback(FrameCallback callback) {
  _frameCallbacks.remove(callback);
  // There is no way to unschedule persistent frame callback in Flutter.
}

class _CustomMultiChildLayout extends CustomMultiChildLayout {
  const _CustomMultiChildLayout({
    required super.delegate,
    required super.children,
  });

  @override
  RenderCustomMultiChildLayoutBox createRenderObject(BuildContext context) {
    return _RenderCustomMultiChildLayoutBox(delegate: delegate);
  }
}

class _RenderCustomMultiChildLayoutBox extends RenderCustomMultiChildLayoutBox {
  _RenderCustomMultiChildLayoutBox({
    required super.delegate,
  });

  static RenderBox? _currentLayout;

  @override
  void performLayout() {
    _currentLayout = this;
    // Relax layout check - we need to be able to get transform to root
    // during layout call, which may involve querying size of unrelated
    // widgets.
    invokeLayoutCallback((constraints) {
      super.performLayout();
    });
    _currentLayout = null;
  }
}
