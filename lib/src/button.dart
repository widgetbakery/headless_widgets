import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:headless/src/control.dart';

import 'mouse_capture.dart';

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
    this.onPressedDown,
    this.onKeyEvent,
    this.child,
    required this.builder,
    this.focusNode,
    this.tapToFocus = false,
    this.pressDownDelay = Duration.zero,
    this.keyUpTimeout,
    this.selected = SelectionState.off,
    this.cursor = SystemMouseCursors.basic,
    this.hitTestBehavior = HitTestBehavior.deferToChild,
    this.isSemanticButton = true,
    this.touchExtraTolerance = EdgeInsets.zero,
  });

  final MouseCursor cursor;
  final SelectionState selected;
  final VoidCallback? onPressed;
  final FutureOr<void> Function()? onPressedDown;
  final KeyEventResult? Function(KeyEvent)? onKeyEvent;
  final FocusNode? focusNode;
  final Widget? child;
  final ButtonBuilder builder;
  final bool tapToFocus;
  final bool isSemanticButton;
  final EdgeInsets touchExtraTolerance;
  final Duration pressDownDelay;

  /// If set the button will be considered pressed when `keyUpTimeout`
  /// elapsed after the key down event.
  final Duration? keyUpTimeout;

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

class _ButtonState extends State<Button> with MouseCapture {
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
  bool _futurePressed = false;

  bool get _pressed => (_tracked && _inside) || _keyPressed || _futurePressed;

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
        _futurePressed = futurePressed;
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

    if (pressedBefore && !_keyPressed && !_tracked && !_futurePressed && !cancelled) {
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
      widget.onPressed?.call();
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
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        _update(keyPressed: true);
        return KeyEventResult.handled;
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        _update(keyPressed: false);
        return KeyEventResult.handled;
      }
    } else if (event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
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
    if (kind == PointerDeviceKind.mouse) {
      captureMouse();
    }
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
    }
    final isInside = bounds.contains(details.localPosition);
    _update(inside: isInside);
  }

  void _onPanEnd(DragEndDetails _) {
    _update(pointerPressed: false, inside: false);
    releaseMouse();
  }

  void _onPanCancel() {
    _update(pointerPressed: false, inside: false, cancelled: true);
    releaseMouse();
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
    int currentPointer() => _panGestureRecognizer!._lastPointerDownEvent!.pointer;
    PointerDeviceKind currentDeviceKind() => _panGestureRecognizer!._lastPointerDownEvent!.kind;
    return {
      TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
        () => TapGestureRecognizer(),
        (instance) {
          instance.onTapUp = _onTapUp;
        },
      ),
      _PanGestureRecognizer: GestureRecognizerFactoryWithHandlers<_PanGestureRecognizer>(
          () => _PanGestureRecognizer(), (instance) {
        _panGestureRecognizer = instance;
        instance.onDown = (details) {
          if (_buttonGroup != null) {
            _buttonGroup!._onPanDown(currentPointer(), currentDeviceKind(), details);
          } else {
            _onPanDown(details, currentDeviceKind());
          }
        };
        instance.onUpdate = (details) {
          if (_buttonGroup != null) {
            _buttonGroup!._onPanUpdate(currentPointer(), currentDeviceKind(), details);
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
    final state = ButtonState(
      selected: widget.selected,
      enabled: _enabled,
      focused: _enabled && focusNode.hasFocus,
      hovered: _enabled && _hovered && !_tracked,
      pressed: _enabled && _pressed,
      tracked: _enabled && _tracked,
    );
    return Semantics(
      button: widget.isSemanticButton,
      container: true,
      enabled: _enabled,
      onTap: widget.onPressed,
      child: Focus.withExternalFocusNode(
        focusNode: focusNode,
        onFocusChange: (_) {
          _focusDidChange();
        },
        child: CaptureAwareMouseRegion(
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

  void _onPanDown(int pointer, PointerDeviceKind deviceKind, DragDownDetails details) {
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

  void _onPanUpdate(int pointer, PointerDeviceKind deviceKind, DragUpdateDetails details) {
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
        DragDownDetails(globalPosition: details.globalPosition, localPosition: localPosition),
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
