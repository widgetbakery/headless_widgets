import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'control.dart';
import 'hover_region.dart';

typedef ButtonState = ControlState;

typedef ButtonBuilder = Widget Function(
  BuildContext context,
  ButtonState state,
  Widget? child,
);

class Button extends StatefulWidget {
  const Button({
    super.key,
    this.onPressed,
    this.child,
    required this.builder,
    this.onPressedDown,
    this.pressDownDelay = Duration.zero,
    this.onKeyEvent,
    this.focusNode,
    this.tapToFocus = false,
    this.keyUpTimeout,
    this.pressOnEnterKey = false,
    this.selected = SelectionState.off,
    this.cursor = SystemMouseCursors.basic,
    this.hitTestBehavior = HitTestBehavior.deferToChild,
    this.isSemanticButton = true,
    this.touchExtraTolerance = EdgeInsets.zero,
    this.mouseExtraTolerance = EdgeInsets.zero,
  });

  /// Callback fired when button is pressed and released.
  ///
  /// If [onPressed] returns a [Future], the button will be considered
  /// pressed until the future completes.
  final FutureOr<void> Function()? onPressed;

  /// Callback fired when button is pressed down, but not released yet.
  /// The amount of time button has to be pressed down for the callback to
  /// fire is determined by [pressDownDelay].
  ///
  /// In case when [onPressedDown] is fired, [onPressed] will not be fired.
  ///
  /// If [onPressedDown] returns a [Future], the button will be considered
  /// pressed until the future completes.
  final FutureOr<void> Function()? onPressedDown;

  /// Controls the amount of time button has to be pressed down for
  /// [onPressedDown] to fire. Defaults to [Duration.zero].
  /// With non-zero [pressDownDelay] it is possible for long press to
  /// trigger [onPressedDown], while short click will trigger [onPressed].
  final Duration pressDownDelay;

  /// Optional child to be passed to [builder].
  final Widget? child;

  /// Builder responsible for rendering the button.
  final ButtonBuilder builder;

  final MouseCursor cursor;
  final SelectionState selected;

  /// Whether keyboard enter key should trigger [onPressed] callback.
  /// on MacOS it is customary for button to be only submitted when pressing
  /// space. On Windows and Linux, pressing enter key on focused button should
  /// trigger [onPressed] callback as well.
  final bool pressOnEnterKey;

  /// Optional callback to be called when key event is received.
  final KeyEventResult? Function(KeyEvent)? onKeyEvent;

  /// Optional focus node to be used for this button. If not specified
  /// button will manage the focus node internally.
  final FocusNode? focusNode;

  /// If set to true, button will request focus when tapped. This is common
  /// behavior on Windows.
  final bool tapToFocus;

  /// If set to true, button will be considered a button in accessibility
  /// tree. Defaults to true.
  final bool isSemanticButton;

  /// Extra inset to be added to button bounds on touch devices when determining
  /// whether button is considered pressed while being in [ControlState.tracked] state.
  final EdgeInsets touchExtraTolerance;

  /// Extra inset to be added to button bounds for mouse devices when determining
  /// whether button is considered pressed while being in [ControlState.tracked] state.
  final EdgeInsets mouseExtraTolerance;

  /// If set the button will be considered pressed when `keyUpTimeout`
  /// elapsed after the key down event. This is common behavior on macOS
  /// and Linux.
  final Duration? keyUpTimeout;

  /// Controls how the button behaves during hit testing.
  final HitTestBehavior hitTestBehavior;

  @override
  State<StatefulWidget> createState() => _ButtonState();
}

class ButtonGroup extends StatefulWidget {
  const ButtonGroup({
    super.key,
    required this.child,
    this.onActiveButtonChanged,
    this.allowedDeviceKind = const {PointerDeviceKind.touch},
  });

  final Widget child;
  final VoidCallback? onActiveButtonChanged;
  final Set<PointerDeviceKind> allowedDeviceKind;

  @override
  State<StatefulWidget> createState() => _ButtonGroupState();
}

//
//
//

class _ButtonState extends State<Button> {
  late FocusNode focusNode;

  @override
  void initState() {
    super.initState();

    focusNode = widget.focusNode ?? FocusNode(debugLabel: '$Button');
    focusNode.onKeyEvent = _onKeyEvent;
    focusNode.canRequestFocus = _enabled;
  }

  void _focusDidChange() {
    _keyUpTimer?.cancel();
    _keyUpTimer = null;

    setState(() {});

    if (focusNode.hasFocus) {
      final ro = context.findRenderObject();
      if (ro != null) {
        ro.showOnScreen();
      }
    } else if (_keyPressed) {
      _keyPressed = false;
    }
  }

  final _detector = GlobalKey();

  bool _hovered = false;
  bool _inside = false;
  bool _tracked = false;
  bool _keyPressed = false;
  bool _waitingOnFuture = false;

  bool get _pressed => (_tracked && _inside) || _keyPressed;

  bool get _enabled => widget.onPressed != null || widget.onPressedDown != null;

  void _update({
    bool? hovered,
    bool? inside,
    bool? pointerPressed,
    bool? keyPressed,
    bool? futurePressed,
    bool cancelled = false,
  }) {
    final pressedBefore = _pressed;
    setState(() {
      if (hovered != null) {
        _hovered = hovered;
      }
      if (inside != null) {
        _inside = inside;
      }
      if (pointerPressed != null) {
        _tracked = pointerPressed;
      }
      if (keyPressed != null) {
        _keyPressed = keyPressed;
      }
      if (futurePressed != null) {
        _waitingOnFuture = futurePressed;
      }
    });
    if (!pressedBefore && _pressed) {
      if (widget.onPressedDown != null) {
        assert(_pressedDownTimer == null);
        void handlePressDown() {
          _didFireLongPress = true;
          final res = widget.onPressedDown?.call();
          if (res is Future) {
            _update(futurePressed: true);
            res.then((value) {
              _update(futurePressed: false);
            }, onError: (error) {
              _update(futurePressed: false);
            });
          }
        }

        if (widget.pressDownDelay == Duration.zero) {
          handlePressDown();
        } else {
          _pressedDownTimer = Timer(widget.pressDownDelay, () {
            _pressedDownTimer = null;
            handlePressDown();
          });
        }
      }
    }

    if (pressedBefore &&
        !_keyPressed &&
        !_tracked &&
        !_waitingOnFuture &&
        !cancelled) {
      if (!_didFireLongPress) {
        _onPressed();
      }
    }
    if (!_pressed) {
      _pressedDownTimer?.cancel();
      _pressedDownTimer = null;
      _didFireLongPress = false;
    }
    if (!pressedBefore &&
        keyPressed == true &&
        widget.keyUpTimeout != null &&
        widget.onPressedDown == null) {
      _keyUpTimer = Timer(widget.keyUpTimeout!, () {
        _keyUpTimer = null;
        // Timer should be invalidated when unsetting _keyPressed;
        assert(_keyPressed);
        _update(keyPressed: false);
      });
    }
  }

  void _onPressed() {
    if (widget.onPressed != null) {
      final res = widget.onPressed?.call();
      if (res is Future) {
        _update(futurePressed: true);
        res.then((value) {
          _update(futurePressed: false);
        }, onError: (error) {
          _update(futurePressed: false);
        });
      }
    }
    _keyUpTimer?.cancel();
    _keyUpTimer = null;
  }

  Timer? _keyUpTimer;
  Timer? _pressedDownTimer;

  bool _didFireLongPress = false;

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    assert(node == focusNode);
    if (!_enabled) {
      return KeyEventResult.ignored;
    }
    final widgetResult = widget.onKeyEvent?.call(event);
    if (widgetResult != null) {
      return widgetResult;
    }
    bool isSubmitKey = event.logicalKey == LogicalKeyboardKey.space ||
        (widget.pressOnEnterKey &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter));

    if (isSubmitKey) {
      if (event is KeyDownEvent) {
        _update(keyPressed: true);
        return KeyEventResult.handled;
      } else if (event is KeyUpEvent) {
        _update(keyPressed: false);
        return KeyEventResult.handled;
      } else if (event is KeyRepeatEvent) {
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  void didUpdateWidget(covariant Button oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != null && widget.focusNode != focusNode) {
      focusNode.onKeyEvent = null;
      if (oldWidget.focusNode != null) {
        focusNode.dispose();
      }
      focusNode = widget.focusNode!;
      focusNode.onKeyEvent = _onKeyEvent;
    }
    focusNode.canRequestFocus = _enabled;
  }

  @override
  void dispose() {
    super.dispose();
    if (widget.focusNode != focusNode) {
      focusNode.dispose();
    }
    _keyUpTimer?.cancel();
    _keyUpTimer = null;
    _pressedDownTimer?.cancel();
    _pressedDownTimer = null;
    _buttonGroup?._buttons.remove(this);
  }

  void _onTapUp(TapUpDetails details) {
    if (!_tracked && !_inside) {
      // These have been cleared by pan gesture recognizer cancel. Revert
      // so that _update fires onPressed callback.
      _tracked = true;
      _inside = true;
    }
    _update(inside: false, pointerPressed: false);
  }

  void _onPanDown(DragDownDetails details, PointerDeviceKind kind) {
    _update(inside: true, pointerPressed: true);
    if (widget.tapToFocus) {
      // This is an oversight in how traversal is implemented in Flutter
      // currently. Manually changing focus doesn't reset traversal history,
      // which can result in unexpected directional movement after.
      FocusTraversalGroup.of(context)
          // ignore: invalid_use_of_protected_member
          .invalidateScopeData(focusNode.nearestScope!);
      FocusScope.of(context).requestFocus(focusNode);
    }
  }

  void _onPanUpdate(DragUpdateDetails details, PointerDeviceKind kind) {
    Rect bounds = (Offset.zero & context.size!);
    if (kind == PointerDeviceKind.touch) {
      bounds = widget.touchExtraTolerance.inflateRect(bounds);
    } else if (kind == PointerDeviceKind.mouse) {
      bounds = widget.mouseExtraTolerance.inflateRect(bounds);
    }
    final isInside = bounds.contains(details.localPosition);
    _update(inside: isInside);
  }

  void _onPanEnd(DragEndDetails _) {
    _update(pointerPressed: false, inside: false);
  }

  void _onPanCancel() {
    _update(pointerPressed: false, inside: false, cancelled: true);
  }

  _PanGestureRecognizer? _panGestureRecognizer;

  _ButtonGroupState? _buttonGroup;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _buttonGroup?._buttons.remove(this);
    _buttonGroup = context.findAncestorStateOfType<_ButtonGroupState>();
    _buttonGroup?._buttons.add(this);
  }

  Map<Type, GestureRecognizerFactory> _buildGestures() {
    int currentPointer() =>
        _panGestureRecognizer!._lastPointerDownEvent!.pointer;
    PointerDeviceKind currentDeviceKind() =>
        _panGestureRecognizer!._lastPointerDownEvent!.kind;
    return {
      TapGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
        () => TapGestureRecognizer(),
        (instance) {
          instance.onTapUp = _onTapUp;
        },
      ),
      _PanGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<_PanGestureRecognizer>(
              () => _PanGestureRecognizer(), (instance) {
        _panGestureRecognizer = instance;
        instance.onDown = (details) {
          if (_buttonGroup != null) {
            _buttonGroup!
                ._onPanDown(currentPointer(), currentDeviceKind(), details);
          } else {
            _onPanDown(details, currentDeviceKind());
          }
        };
        instance.onUpdate = (details) {
          if (_buttonGroup != null) {
            _buttonGroup!
                ._onPanUpdate(currentPointer(), currentDeviceKind(), details);
          } else {
            _onPanUpdate(details, currentDeviceKind());
          }
        };
        instance.onEnd = (details) {
          if (_buttonGroup != null) {
            _buttonGroup!._onPanEnd(currentPointer(), details);
          } else {
            _onPanEnd(details);
          }
        };
        instance.onCancel = () {
          if (_buttonGroup != null) {
            _buttonGroup!._onPanCancel(
              _panGestureRecognizer!._lastPointerDownEvent?.pointer ?? 0,
            );
          } else {
            _onPanCancel();
          }
        };
      }),
    };
  }

  @override
  Widget build(BuildContext context) {
    bool noButtonInGroupTracked() {
      if (_buttonGroup == null) {
        return true;
      }
      return _buttonGroup!._buttons.every(
        (element) => !element._tracked,
      );
    }

    final state = ButtonState(
      selected: widget.selected,
      enabled: _enabled,
      focused: _enabled && focusNode.hasFocus,
      hovered: _enabled && _hovered && !_tracked && noButtonInGroupTracked(),
      pressed: _enabled && (_pressed || _waitingOnFuture),
      tracked: _enabled && _tracked,
    );
    return Semantics(
      button: widget.isSemanticButton,
      container: true,
      enabled: _enabled,
      onTap: _onPressed,
      child: Focus.withExternalFocusNode(
        focusNode: focusNode,
        onFocusChange: (_) {
          _focusDidChange();
        },
        child: HoverRegion(
          cursor: _enabled ? widget.cursor : MouseCursor.defer,
          onEnter: (event) {
            setState(() {
              _hovered = true;
            });
          },
          onExit: (event) {
            setState(() {
              _hovered = false;
            });
          },
          child: RawGestureDetector(
            behavior: widget.hitTestBehavior,
            key: _detector,
            gestures: _buildGestures(),
            child: ControlStateProvider(
              state: state,
              child: widget.builder(context, state, widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanGestureRecognizer extends PanGestureRecognizer {
  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) {
    return false;
  }

  PointerDownEvent? _lastPointerDownEvent;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _lastPointerDownEvent = event;
    super.addAllowedPointer(event);
  }

  @override
  bool isPointerAllowed(PointerEvent event) {
    if (event.kind == PointerDeviceKind.mouse) {
      return event.buttons == 1;
    }
    return super.isPointerAllowed(event);
  }
}

class _ButtonGroupState extends State<ButtonGroup> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  _ButtonState? buttonForOffset(Offset globalPosition) {
    for (final button in _buttons) {
      if (!button._enabled) {
        continue;
      }
      final local = getLocalPosition(globalPosition, button);
      final rect = (Offset.zero & button.context.size!);
      if (rect.contains(local)) {
        return button;
      }
    }
    return null;
  }

  Offset getLocalPosition(Offset globalPosition, _ButtonState state) {
    final ro = state.context.findRenderObject()!;
    final transform = ro.getTransformTo(null)..invert();
    return MatrixUtils.transformPoint(transform, globalPosition);
  }

  void _onPanDown(
    int pointer,
    PointerDeviceKind deviceKind,
    DragDownDetails details,
  ) {
    assert(!_pointerToButton.containsKey(pointer));
    final button = buttonForOffset(details.globalPosition);
    if (button != null) {
      _pointerToButton[pointer] = button;
      final detailsTranslated = DragDownDetails(
        globalPosition: details.globalPosition,
        localPosition: getLocalPosition(details.globalPosition, button),
      );
      button._onPanDown(detailsTranslated, deviceKind);
    }
  }

  void _onPanUpdate(
    int pointer,
    PointerDeviceKind deviceKind,
    DragUpdateDetails details,
  ) {
    final button = widget.allowedDeviceKind.contains(deviceKind)
        ? buttonForOffset(details.globalPosition) ?? _pointerToButton[pointer]
        : _pointerToButton[pointer];
    if (button == null) {
      return; // can happen when starting with disabled button.
    }
    final localPosition = getLocalPosition(details.globalPosition, button);

    if (button != _pointerToButton[pointer]) {
      _pointerToButton[pointer]?._onPanCancel();
      _pointerToButton[pointer]?._onPanEnd(DragEndDetails());
      _pointerToButton[pointer] = button;
      widget.onActiveButtonChanged?.call();
      button._onPanDown(
        DragDownDetails(
          globalPosition: details.globalPosition,
          localPosition: localPosition,
        ),
        deviceKind,
      );
    }

    final detailsTranslated = DragUpdateDetails(
      globalPosition: details.globalPosition,
      localPosition: localPosition,
    );
    button._onPanUpdate(detailsTranslated, deviceKind);
  }

  void _onPanEnd(int pointer, DragEndDetails details) {
    final button = _pointerToButton.remove(pointer);
    if (button != null) {
      button._onPanEnd(details);
    }
  }

  void _onPanCancel(int pointer) {
    final button = _pointerToButton.remove(pointer);
    if (button != null) {
      button._onPanCancel();
    }
  }

  final _pointerToButton = <int, _ButtonState>{};
  final _buttons = <_ButtonState>{};
}
