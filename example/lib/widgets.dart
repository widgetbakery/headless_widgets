import 'dart:async';

import 'package:cupertino_rrect/cupertino_rrect.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:headless_widgets/headless_widgets.dart';
import 'package:pixel_snap/widgets.dart';

class FocusIndicator extends StatelessWidget {
  const FocusIndicator({
    super.key,
    required this.focused,
    required this.child,
    this.readius = 8.0,
  });

  final bool focused;
  final Widget child;
  final double readius;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.0, end: focused ? 1.0 : 0.0),
      curve: Curves.easeOutQuad,
      duration: focused ? const Duration(milliseconds: 300) : Duration.zero,
      builder: (context, focus, child) {
        return CustomPaint(
          painter: _FocusPainter(
            pixelSnap: PixelSnap.of(context),
            radius: readius,
            focus: focus,
          ),
          child: child,
        );
      },
      child: child,
    );
  }
}

class _FocusPainter extends CustomPainter {
  final double focus;
  final double radius;
  final PixelSnap pixelSnap;

  _FocusPainter({
    required this.pixelSnap,
    required this.focus,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (focus > 0) {
      final opacity = focus;

      final paint = Paint()
        ..color = Colors.deepOrange.shade200.withOpacity(opacity);

      final radius = Radius.circular(this.radius).pixelSnap(pixelSnap);
      var rect = (Offset.zero & size).pixelSnap(pixelSnap).inflate(2);

      canvas.translate(rect.width / 2.0, rect.height / 2.0);
      rect = rect.translate(-rect.width / 2.0, -rect.height / 2.0);

      canvas.scale(
        1.0 + 14.0 / size.width * (1.0 - focus),
        1.0 + 14.0 / size.height * (1.0 - focus),
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FocusPainter oldDelegate) {
    return focus != oldDelegate.focus;
  }
}

class SampleSlider extends StatelessWidget {
  const SampleSlider({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    this.onKeyboardAction,
  });

  final double min;
  final double max;
  final double value;
  final ValueChanged<double>? onChanged;
  final void Function(SliderKeyboardAction action)? onKeyboardAction;

  @override
  Widget build(BuildContext context) {
    return Slider(
      min: min,
      max: max,
      value: value,
      onChanged: onChanged,
      onKeyboardAction: onKeyboardAction,
      animationDuration: const Duration(milliseconds: 200),
      animationCurve: Curves.easeOutCubic,
      geometry: (state, constraints, trackSize, thumbSize) => _geometry(
        state,
        constraints,
        trackSize,
        thumbSize,
        PixelSnap.of(context),
      ),
      thumbBuilder: (context, state) {
        final backgroundColor = switch (state) {
          SliderState(tracked: true) => Colors.blue.shade400,
          SliderState(hovered: true) => Colors.blue.shade50,
          _ => Colors.white,
        };
        return FocusIndicator(
          readius: 12.0,
          focused: state.focused,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border.all(
                color: Colors.blueGrey,
                width: 1,
              ),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      trackBuilder: (context, state, thumbSize) {
        return Container(
          height: thumbSize.height,
          padding: EdgeInsets.symmetric(horizontal: thumbSize.width / 2),
          child: Center(
              child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          )),
        );
      },
    );
  }

  static SliderGeometry _geometry(
    SliderState state,
    BoxConstraints constraints,
    Size thumbSize,
    Size trackSize,
    PixelSnap ps,
  ) {
    return SliderGeometry(
      sliderSize: Size(constraints.maxWidth, thumbSize.height),
      thumbPosition: Offset(
        ps(
          (constraints.maxWidth - thumbSize.width) * (state.effectiveFraction),
        ),
        0,
      ),
    );
  }
}

class SampleButton extends StatelessWidget {
  const SampleButton({
    super.key,
    required this.child,
    this.tapToFocus = false,
    this.onPressed,
    this.onPressedDown,
    this.keyUpTimeout,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final FutureOr<void> Function()? onPressedDown;
  final bool tapToFocus;
  final Duration? keyUpTimeout;

  Widget _builder(
    BuildContext context,
    ButtonState state,
    Widget? child,
  ) {
    final ps = PixelSnap.of(context);
    final borderColor = switch (state) {
      ButtonState(enabled: false) => Colors.blue.shade200,
      ButtonState(pressed: true) => Colors.blue.shade400,
      _ => Colors.blue.shade300,
    };
    final backgroundColor = switch (state) {
      ButtonState(pressed: true) => Colors.blue.shade400,
      ButtonState(hovered: true) ||
      ButtonState(tracked: true) =>
        Colors.blue.shade50,
      _ => Colors.white,
    };
    final textColor = switch (state) {
      ButtonState(enabled: false) => Colors.grey.shade400,
      ButtonState(pressed: true) => Colors.white,
      _ => Colors.black,
    };
    final shadowOpacity = switch (state) {
      ButtonState(enabled: false) => 0.2,
      ButtonState(focused: true) => 0.0,
      ButtonState(pressed: true) => 0.15,
      _ => 0.2,
    };
    return FocusIndicator(
      focused: state.focused,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: ShapeDecoration(
          // border: Border.fromBorderSide(
          //   // borderRadius: BorderRadius.circular(6),
          //   BorderSide(color: borderColor, width: 1),
          // ),
          // borderRadius: const BorderRadius.all(Radius.circular(6.0)),
          // boxShadow: [
          //   BoxShadow(
          //     blurStyle: BlurStyle.outer,
          //     color: Colors.black.withOpacity(shadowOpacity),
          //     blurRadius: 3,
          //   ),
          // ],
          shape: CupertinoRectangleBorder(
            // borderRadius: BorderRadius.circular(6),
            borderRadius:
                const BorderRadius.all(Radius.circular(6.0)).pixelSnap(ps),
            side: BorderSide(color: borderColor, width: 1).pixelSnap(ps),
          ),
          shadows: [
            BoxShadow(
              blurStyle: BlurStyle.outer,
              color: Colors.black.withOpacity(shadowOpacity),
              blurRadius: 3,
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(backgroundColor, Colors.white, 0.2)!,
              backgroundColor,
            ],
          ),
        ),
        child: Container(
          child: DefaultTextStyle.merge(
            style: TextStyle(
              height: 1.17,
              color: textColor,
            ),
            child: child!,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Button(
      tapToFocus: tapToFocus,
      onPressed: onPressed,
      onPressedDown: onPressedDown,
      keyUpTimeout: keyUpTimeout,
      builder: _builder,
      child: child,
    );
  }
}
