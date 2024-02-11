import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'focusable_control_mixin.dart';
import 'hover_region.dart';
import 'sized_custom_layout.dart';

class SliderState {
  SliderState({
    required this.axis,
    required this.focused,
    required this.hovered,
    required this.tracked,
    required this.enabled,
    required this.min,
    required this.max,
    required this.effectiveValue,
    required this.targetValue,
    this.secondaryValue,
    required this.textDirection,
  });

  final Axis axis;
  final bool focused;
  final bool hovered;
  final bool tracked;
  final bool enabled;
  final double min;
  final double max;
  final double effectiveValue;
  final double targetValue;
  final double? secondaryValue;
  final TextDirection textDirection;

  double get effectiveFraction {
    return (effectiveValue - min) / (max - min);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SliderState &&
          other.axis == axis &&
          other.focused == focused &&
          other.hovered == hovered &&
          other.tracked == tracked &&
          other.enabled == enabled &&
          other.min == min &&
          other.max == max &&
          other.effectiveValue == effectiveValue &&
          other.targetValue == targetValue &&
          other.secondaryValue == secondaryValue);

  @override
  int get hashCode => Object.hash(
        axis,
        focused,
        hovered,
        tracked,
        enabled,
        min,
        max,
        effectiveValue,
        targetValue,
        secondaryValue,
      );

  SliderState copyWith({
    Axis? axis,
    bool? focused,
    bool? hovered,
    bool? tracked,
    bool? enabled,
    double? min,
    double? max,
    double? effectiveValue,
    double? targetValue,
    double? secondaryValue,
    TextDirection? textDirection,
  }) {
    return SliderState(
      axis: axis ?? this.axis,
      focused: focused ?? this.focused,
      hovered: hovered ?? this.hovered,
      tracked: tracked ?? this.tracked,
      enabled: enabled ?? this.enabled,
      min: min ?? this.min,
      max: max ?? this.max,
      effectiveValue: effectiveValue ?? this.effectiveValue,
      targetValue: targetValue ?? this.targetValue,
      secondaryValue: secondaryValue ?? this.secondaryValue,
      textDirection: textDirection ?? this.textDirection,
    );
  }
}

class SliderGeometry {
  SliderGeometry({
    required this.sliderSize,
    this.trackPosition = Offset.zero,
    required this.thumbPosition,
  });

  /// Overall size of the slider.
  final Size sliderSize;

  /// The top left offset of track.
  final Offset trackPosition;

  /// The top left offset of thumb.
  final Offset thumbPosition;
}

typedef TrackConstraintsProvider = BoxConstraints Function(
  SliderState state,
  BoxConstraints constraints,
  Size thumbSize,
);

typedef SliderGeometryProvider = SliderGeometry Function(
  SliderState state,
  BoxConstraints constraints,
  Size thumbSize,
  Size trackSize,
);

enum SliderKeyboardAction {
  increase,
  decrease,
}

class Slider extends StatefulWidget {
  const Slider({
    super.key,
    this.axis = Axis.horizontal,
    required this.min,
    required this.max,
    required this.value,
    this.secondaryValue,
    this.trackConstraints,
    required this.geometry,
    required this.thumbBuilder,
    required this.trackBuilder,
    this.onChangeStart,
    this.onChangeEnd,
    this.onChanged,
    this.focusNode,
    this.tapToFocus = false,
    this.isSemanticSlider = true,
    this.decorationBuilder,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.linear,
    this.onKeyboardAction,
  })  : assert(min <= max),
        assert(min <= value),
        assert(value <= max);

  final Axis axis;
  final double min;
  final double max;
  final double value;
  final double? secondaryValue;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final ValueChanged<double>? onChanged;
  final void Function(SliderKeyboardAction action)? onKeyboardAction;

  final TrackConstraintsProvider? trackConstraints;
  final SliderGeometryProvider geometry;
  final Duration animationDuration;
  final Curve animationCurve;

  final Widget Function(
    BuildContext,
    SliderState,
    Widget child,
  )? decorationBuilder;

  final Widget Function(BuildContext context, SliderState state) thumbBuilder;
  final Widget Function(
    BuildContext context,
    SliderState state,
    Size thubSize,
  ) trackBuilder;

  /// Optional focus node to be used for this slider. If not specified
  /// slider will manage the focus node internally.
  final FocusNode? focusNode;

  /// If set to true, slider will request focus when tapped. This is common
  /// behavior on Windows.
  final bool tapToFocus;

  /// If set to true, slider will be considered a slider in accessibility
  /// tree. Defaults to true.
  final bool isSemanticSlider;

  @override
  State<StatefulWidget> createState() => _SliderState();
}

class _SliderState extends State<Slider>
    with SingleTickerProviderStateMixin<Slider>, FocusableControlMixin<Slider> {
  late double _effectiveValue;
  late double _animationStartValue;
  late double _targetValue;
  late Ticker _ticker;
  bool _hovered = false;
  bool _tracked = false;

  bool get _enabled => widget.onChanged != null;

  @override
  void initState() {
    super.initState();
    _effectiveValue = widget.value;
    _targetValue = widget.value;
    _ticker = createTicker(_onAnimationTick);
  }

  @override
  KeyEventResult onKeyEvent(FocusNode node, KeyEvent event) {
    final handler = widget.onKeyboardAction;
    if (_enabled && handler != null) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        SliderKeyboardAction? action;
        if (widget.axis == Axis.horizontal) {
          final textDirection = Directionality.of(context);
          if (textDirection == TextDirection.ltr) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              action = SliderKeyboardAction.decrease;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              action = SliderKeyboardAction.increase;
            }
          } else {
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              action = SliderKeyboardAction.decrease;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              action = SliderKeyboardAction.increase;
            }
          }
        } else {
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            action = SliderKeyboardAction.decrease;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            action = SliderKeyboardAction.increase;
          }
        }
        if (action != null) {
          handler(action);
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  void _focusDidChange() {
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onAnimationTick(Duration elapsed) {
    if (elapsed > widget.animationDuration) {
      _ticker.stop();
      setState(() {
        _effectiveValue = _targetValue;
      });
    } else {
      final progress = widget.animationCurve.transform(
          elapsed.inMicroseconds / widget.animationDuration.inMicroseconds);
      final value = lerpDouble(_animationStartValue, _targetValue, progress)!;
      setState(() {
        _effectiveValue = value;
      });
    }
  }

  @override
  void didUpdateWidget(covariant Slider oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_targetValue != widget.value) {
      if (!_tracked ||
          widget.animationDuration == Duration.zero ||
          (_didHaveTicker && !_ticker.isActive)) {
        _effectiveValue = widget.value;
        _targetValue = widget.value;
      } else {
        _targetValue = widget.value;
        if (!_ticker.isActive) {
          _didHaveTicker = true;
          _animationStartValue = _effectiveValue;
          _ticker.start();
        }
      }
    }
  }

  final _layoutKey = GlobalKey();

  void _updateValueOnPointer(Offset globalPosition, {bool didStart = false}) {
    final layout = _layoutKey.currentContext!.findRenderObject() as RenderBox;
    final localPosition = layout.globalToLocal(globalPosition);
    final double min;
    final double max;
    final double d;
    if (widget.axis == Axis.horizontal) {
      min = _thumbCenterMin.dx;
      max = _thumbCenterMax.dx;
      d = localPosition.dx;
    } else {
      min = _thumbCenterMin.dy;
      max = _thumbCenterMax.dy;
      d = localPosition.dy;
    }
    final position = ((d - min) / (max - min)).clamp(0.0, 1.0);
    final value = widget.min + (widget.max - widget.min) * position;
    if (didStart) {
      widget.onChangeStart?.call(value);
    }
    widget.onChanged?.call(value);
  }

  Offset _thumbCenterMin = Offset.zero;
  Offset _thumbCenterMax = Offset.zero;
  Size _thumbSize = Size.infinite;

  bool _didHaveTicker = false;

  void _onDragDown(DragDownDetails details) {
    if (widget.tapToFocus) {
      // This is an oversight in how traversal is implemented in Flutter
      // currently. Manually changing focus doesn't reset traversal history,
      // which can result in unexpected directional movement after.
      FocusTraversalGroup.of(context)
          // ignore: invalid_use_of_protected_member
          .invalidateScopeData(focusNode.nearestScope!);
      FocusScope.of(context).requestFocus(focusNode);
    }
    setState(() {
      _tracked = true;
    });
    _updateValueOnPointer(details.globalPosition, didStart: true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _updateValueOnPointer(details.globalPosition);
  }

  void _onDragEnd(DragEndDetails details) {
    _onDragCancel();
  }

  void _onDragCancel() {
    setState(() {
      _tracked = false;
    });
    _didHaveTicker = false;
    widget.onChangeEnd?.call(widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final state = SliderState(
      axis: widget.axis,
      focused: focusNode.hasFocus,
      hovered: _hovered,
      tracked: _tracked,
      enabled: _enabled,
      min: widget.min,
      max: widget.max,
      effectiveValue: _effectiveValue,
      targetValue: _targetValue,
      secondaryValue: widget.secondaryValue,
      textDirection: Directionality.of(context),
    );

    Widget res = SizedCustomMultiChildLayout(
      key: _layoutKey,
      delegate: _SliderLayoutDelegate(
        state: state,
        geometry: widget.geometry,
        trackConstraints: widget.trackConstraints,
        onHaveThumbRange: (range) {
          _thumbCenterMin = range.$1;
          _thumbCenterMax = range.$2;
        },
        onHaveThumbSize: (size) {
          _thumbSize = size;
        },
      ),
      children: [
        LayoutId(
          id: _SliderElementType.track,
          // Make sure to build after laid out so that w have thumb size.
          child: LayoutBuilder(
            builder: (context, BoxConstraints constraints) {
              assert(_thumbSize.isFinite); // Should be set by layout delegate.
              return widget.trackBuilder(context, state, _thumbSize);
            },
          ),
        ),
        LayoutId(
          id: _SliderElementType.thumb,
          child: Builder(
            builder: (context) => widget.thumbBuilder(context, state),
          ),
        ),
      ],
    );

    if (widget.decorationBuilder != null) {
      res = widget.decorationBuilder!(context, state, res);
    }

    if (widget.axis == Axis.horizontal) {
      res = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragDown: _onDragDown,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        onHorizontalDragCancel: _onDragCancel,
        child: res,
      );
    } else {
      res = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragDown: _onDragDown,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        onVerticalDragCancel: _onDragCancel,
        child: res,
      );
    }

    return Semantics(
      slider: widget.isSemanticSlider,
      enabled: _enabled,
      child: Focus.withExternalFocusNode(
        focusNode: focusNode,
        onFocusChange: (_) {
          _focusDidChange();
        },
        child: HoverRegion(
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
          child: res,
        ),
      ),
    );
  }

  @override
  FocusNode? getWidgetFocusNode(Slider widget) => widget.focusNode;

  @override
  bool get widgetIsEnabled => _enabled;
}

enum _SliderElementType {
  thumb,
  track,
}

class _SliderLayoutDelegate extends SizedMultiChildLayoutDelegate {
  final SliderState state;
  final TrackConstraintsProvider? trackConstraints;
  final SliderGeometryProvider geometry;
  final ValueChanged<(Offset, Offset)> onHaveThumbRange;
  final ValueChanged<Size> onHaveThumbSize;

  _SliderLayoutDelegate({
    required this.state,
    required this.trackConstraints,
    required this.geometry,
    required this.onHaveThumbRange,
    required this.onHaveThumbSize,
  });

  @override
  Size performLayout(BoxConstraints constraints) {
    final thumbSize = layoutChild(
      _SliderElementType.thumb,
      constraints.loosen(),
    );
    onHaveThumbSize(thumbSize);
    final trackConstraints = this.trackConstraints?.call(
              state,
              constraints,
              thumbSize,
            ) ??
        constraints;
    final trackSize = layoutChild(
      _SliderElementType.track,
      trackConstraints,
    );

    final geometry = this.geometry(
      state,
      constraints,
      thumbSize,
      trackSize,
    );

    final geometryMin = this.geometry(
      state.copyWith(effectiveValue: state.min, targetValue: state.min),
      constraints,
      thumbSize,
      trackSize,
    );
    final geometryMax = this.geometry(
      state.copyWith(effectiveValue: state.max, targetValue: state.max),
      constraints,
      thumbSize,
      trackSize,
    );
    final thumbHalfSize = Offset(thumbSize.width / 2, thumbSize.height / 2);
    onHaveThumbRange((
      geometryMin.thumbPosition + thumbHalfSize,
      geometryMax.thumbPosition + thumbHalfSize,
    ));

    positionChild(_SliderElementType.thumb, geometry.thumbPosition);
    positionChild(_SliderElementType.track, geometry.trackPosition);
    return geometry.sliderSize;
  }

  @override
  bool shouldRelayout(covariant _SliderLayoutDelegate oldDelegate) {
    return oldDelegate.state != state;
  }
}
