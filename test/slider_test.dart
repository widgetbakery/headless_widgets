import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headless_widgets/headless_widgets.dart';

import 'test_util.dart';

class _Thumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
    );
  }
}

class _Track extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

BoxConstraints _trackConstraints(
  SliderState state,
  BoxConstraints constraints,
  Size thumbSize,
) {
  return constraints.tighten();
}

SliderGeometry _simpleHorizontalGeometry(SliderState state,
    BoxConstraints constraints, Size thumbSize, Size trackSize) {
  double fraction = state.effectiveFraction;
  if (state.textDirection == TextDirection.rtl) {
    fraction = 1.0 - fraction;
  }
  return SliderGeometry(
    sliderSize: Size(constraints.maxWidth, thumbSize.height),
    trackPosition: Offset.zero,
    thumbPosition: Offset(
      (constraints.maxWidth - thumbSize.width) * fraction,
      0,
    ),
  );
}

SliderGeometry _simpleVerticalGeometry(SliderState state,
    BoxConstraints constraints, Size thumbSize, Size trackSize) {
  // 0 at bottom
  final fraction = 1.0 - state.effectiveFraction;
  return SliderGeometry(
    sliderSize: Size(thumbSize.width, constraints.maxHeight),
    trackPosition: Offset.zero,
    thumbPosition: Offset(
      0,
      (constraints.maxHeight - thumbSize.height) * fraction,
    ),
  );
}

void main() {
  testWidgets('simple pointer interaction - horizontal', (tester) async {
    double value = 0;
    Future<void> pumpSlider() async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 100,
            child: Slider(
              min: 0,
              max: 100,
              value: value,
              trackConstraints: _trackConstraints,
              geometry: _simpleHorizontalGeometry,
              thumbBuilder: (context, state) => _Thumb(),
              trackBuilder: (context, state) => _Track(),
              onChanged: (v) => value = v,
            ),
          ),
        ),
      ));
    }

    await pumpSlider();
    expect(
      tester.getTopLeft(find.byType(_Thumb)),
      tester.getTopLeft(find.byType(Slider)),
    );
    // Tap slider in the middle
    await tester.tapAt(tester.getCenter(find.byType(Slider)));
    expect(value, 50);
    await pumpSlider();
    expect(
      tester.getCenter(find.byType(_Thumb)),
      tester.getCenter(find.byType(Slider)),
    );
    await tester.tapAt(tester.getTopLeft(find.byType(Slider)));
    expect(value, 0);
    await pumpSlider();
    expect(
      tester.getTopLeft(find.byType(_Thumb)),
      tester.getTopLeft(find.byType(Slider)),
    );

    await tester.tapAt(
      tester.getBottomRight(find.byType(Slider)) - const Offset(1, 1),
    );
    expect(value, 100);
    await pumpSlider();
    expect(
      tester.getBottomRight(find.byType(_Thumb)),
      tester.getBottomRight(find.byType(Slider)),
    );
  });
  testWidgets('simple pointer interaction - horizontal (RTL)', (tester) async {
    double value = 0;
    Future<void> pumpSlider() async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SizedBox(
            width: 100,
            child: Slider(
              min: 0,
              max: 100,
              value: value,
              geometry: _simpleHorizontalGeometry,
              trackConstraints: _trackConstraints,
              thumbBuilder: (context, state) => _Thumb(),
              trackBuilder: (context, state) => _Track(),
              onChanged: (v) => value = v,
            ),
          ),
        ),
      ));
    }

    await pumpSlider();
    expect(
      tester.getTopRight(find.byType(_Thumb)),
      tester.getTopRight(find.byType(Slider)),
    );
    // Tap slider in the middle
    await tester.tapAt(tester.getCenter(find.byType(Slider)));
    expect(value, 50);
    await pumpSlider();
    expect(
      tester.getCenter(find.byType(_Thumb)),
      tester.getCenter(find.byType(Slider)),
    );
    await tester.tapAt(tester.getTopLeft(find.byType(Slider)));
    expect(value, 100);
    await pumpSlider();
    expect(
      tester.getTopLeft(find.byType(_Thumb)),
      tester.getTopLeft(find.byType(Slider)),
    );

    await tester.tapAt(
      tester.getBottomRight(find.byType(Slider)) - const Offset(1, 1),
    );
    expect(value, 0);
    await pumpSlider();
    expect(
      tester.getBottomRight(find.byType(_Thumb)),
      tester.getBottomRight(find.byType(Slider)),
    );
  });

  testWidgets('simple pointer interaction - vertical', (tester) async {
    double value = 0;
    Future<void> pumpSlider() async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            height: 100,
            child: Slider(
              axis: Axis.vertical,
              min: 0,
              max: 100,
              value: value,
              geometry: _simpleVerticalGeometry,
              trackConstraints: _trackConstraints,
              thumbBuilder: (context, state) => _Thumb(),
              trackBuilder: (context, state) => _Track(),
              onChanged: (v) => value = v,
            ),
          ),
        ),
      ));
    }

    await pumpSlider();
    expect(
      tester.getBottomLeft(find.byType(_Thumb)),
      tester.getBottomLeft(find.byType(Slider)),
    );
    // Tap slider in the middle
    await tester.tapAt(tester.getCenter(find.byType(Slider)));
    expect(value, 50);
    await pumpSlider();
    expect(
      tester.getCenter(find.byType(_Thumb)),
      tester.getCenter(find.byType(Slider)),
    );
    await tester.tapAt(tester.getTopLeft(find.byType(Slider)));
    expect(value, 100);
    await pumpSlider();
    expect(
      tester.getTopLeft(find.byType(_Thumb)),
      tester.getTopLeft(find.byType(Slider)),
    );

    await tester.tapAt(
      tester.getBottomRight(find.byType(Slider)) - const Offset(1, 1),
    );
    expect(value, 0);
    await pumpSlider();
    expect(
      tester.getBottomRight(find.byType(_Thumb)),
      tester.getBottomRight(find.byType(Slider)),
    );
  });

  testWidgets('pointer interaction animation', (tester) async {
    double value = 0;
    Future<void> pumpSlider() async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 100,
            child: Slider(
              animationDuration: const Duration(milliseconds: 200),
              min: 0,
              max: 100,
              value: value,
              geometry: _simpleHorizontalGeometry,
              trackConstraints: _trackConstraints,
              thumbBuilder: (context, state) => _Thumb(),
              trackBuilder: (context, state) => _Track(),
              onChanged: (v) => value = v,
            ),
          ),
        ),
      ));
    }

    for (int i = 0; i < 2; ++i) {
      await pumpSlider();

      final gesture =
          await tester.createPlatformGesture(initialLocation: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byType(Slider)));
      await gesture.down(tester.getCenter(find.byType(Slider)));

      expect(value, 50);
      await pumpSlider();

      {
        final thumbCenter = tester.getCenter(find.byType(_Thumb));
        expect(
            thumbCenter.dx, lessThan(tester.getCenter(find.byType(Slider)).dx));
      }

      // Expect animation, but only once per touch.
      final frames = await tester.pumpAndSettle();
      expect(frames > 1, isTrue);

      expect(
        tester.getCenter(find.byType(_Thumb)),
        tester.getCenter(find.byType(Slider)),
      );

      await gesture.moveTo(tester.getTopLeft(find.byType(Slider)));
      expect(value, 0);
      await pumpSlider();

      // During drag after animation is finished move the slider immediately.
      expect(
        tester.getTopLeft(find.byType(_Thumb)),
        tester.getTopLeft(find.byType(Slider)),
      );

      await gesture.up();
      await tester.pump();
    }
  });
}
