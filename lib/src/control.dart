import 'package:flutter/widgets.dart';

enum SelectionState {
  on,
  off,
  mixed,
}

class ControlState {
  ControlState({
    this.selected = SelectionState.off,
    this.enabled = false,
    this.focused = false,
    this.hovered = false,
    this.pressed = false,
    this.tracked = false,
  });

  /// Determines selection state of the control.
  final SelectionState selected;

  /// Control is enabled and can be interacted with.
  final bool enabled;

  /// Control has keyboard focus.
  final bool focused;

  /// Control is being hovered over by a pointer.
  final bool hovered;

  /// Control is being pressed. When pointer is released without leaving the
  /// control, the control will receive a tap event.
  final bool pressed;

  /// Control is receiving pointer events but the pointer may or may not be
  /// hovering over the control.
  final bool tracked;

  /// Returns the state of the nearest control above this context, or null if
  /// there is no control in the tree above this context.
  static ControlState? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ControlStateProvider>()?.state;
  }

  /// Returns the state of the nearest control above this context.
  static ControlState of(BuildContext context) {
    final state = ControlState.maybeOf(context);
    assert(state != null, 'ButtonState.of() called with a context that does not contain a Button.');
    return state!;
  }

  @override
  bool operator ==(Object other) {
    return other is ControlState &&
        other.selected == selected &&
        other.enabled == enabled &&
        other.focused == focused &&
        other.hovered == hovered &&
        other.pressed == pressed &&
        other.tracked == tracked;
  }

  @override
  int get hashCode => Object.hash(
        selected,
        enabled,
        focused,
        hovered,
        pressed,
        tracked,
      );

  @override
  String toString() {
    final res = StringBuffer();
    void append(String text) {
      if (res.isNotEmpty) {
        res.write(', ');
      }
      res.write(text);
    }

    if (selected != SelectionState.off) {
      append(selected.name);
    }
    if (enabled) {
      append('enabled');
    }
    if (focused) {
      append('focused');
    }
    if (hovered) {
      append('hovered');
    }
    if (pressed) {
      append('pressed');
    }
    if (tracked) {
      append('tracked');
    }
    return 'ControlState($res)';
  }
}

class ControlStateProvider extends InheritedWidget {
  const ControlStateProvider({
    super.key,
    required super.child,
    required this.state,
  });

  final ControlState state;

  @override
  bool updateShouldNotify(covariant ControlStateProvider oldWidget) {
    return oldWidget.state != state;
  }
}
