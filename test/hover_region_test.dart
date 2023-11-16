import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headless_widgets/headless_widgets.dart';

import 'test_util.dart';

class _MouseRegionState {
  bool isInside = false;
}

class _MouseRegion extends StatelessWidget {
  const _MouseRegion({
    required this.state,
    required this.child,
  });

  final _MouseRegionState state;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return HoverRegion(
      onEnter: (_) {
        state.isInside = true;
      },
      onExit: (_) {
        state.isInside = false;
      },
      child: child,
    );
  }
}

void main() {
  testWidgets('hover works normally', (tester) async {
    final regionContainer = _MouseRegionState();
    final regionInner1 = _MouseRegionState();
    final regionOuter1 = _MouseRegionState();
    final regionInner2 = _MouseRegionState();
    final regionOuter2 = _MouseRegionState();

    const widget1 = Key('Widget1');
    const widget2 = Key('Widget2');

    await tester.pumpWidget(
      Align(
        alignment: Alignment.topLeft,
        child: _MouseRegion(
          state: regionContainer,
          child: Padding(
            padding: const EdgeInsets.all(100),
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                _MouseRegion(
                  state: regionOuter1,
                  child: _MouseRegion(
                    state: regionInner1,
                    child: const SizedBox.square(key: widget1, dimension: 100),
                  ),
                ),
                _MouseRegion(
                  state: regionOuter2,
                  child: _MouseRegion(
                    state: regionInner2,
                    child: const SizedBox.square(key: widget2, dimension: 100),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(regionContainer.isInside, false);
    expect(regionOuter1.isInside, false);
    expect(regionInner1.isInside, false);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    for (int i = 0; i < 2; ++i) {
      expect(regionContainer.isInside, true);
      expect(regionOuter1.isInside, false);
      expect(regionInner1.isInside, false);

      await gesture.moveTo(tester.getCenter(find.byKey(widget1)));

      expect(regionContainer.isInside, true);
      expect(regionOuter1.isInside, true);
      expect(regionInner1.isInside, true);
      expect(regionOuter2.isInside, false);
      expect(regionInner2.isInside, false);

      await gesture.moveTo(tester.getCenter(find.byKey(widget2)));

      expect(regionContainer.isInside, true);
      expect(regionOuter1.isInside, false);
      expect(regionInner1.isInside, false);
      expect(regionOuter2.isInside, true);
      expect(regionInner2.isInside, true);
    }
  });

  testWidgets('capture-like behavior works', (tester) async {
    final regionContainer = _MouseRegionState();
    final regionInner1 = _MouseRegionState();
    final regionOuter1 = _MouseRegionState();
    final regionInner2 = _MouseRegionState();
    final regionOuter2 = _MouseRegionState();

    const widget1 = Key('Widget1');
    const widget2 = Key('Widget2');

    await tester.pumpWidget(
      Align(
        alignment: Alignment.topLeft,
        child: _MouseRegion(
          state: regionContainer,
          child: Padding(
            padding: const EdgeInsets.all(100),
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                _MouseRegion(
                  state: regionOuter1,
                  child: _MouseRegion(
                    state: regionInner1,
                    child: const SizedBox.square(
                      key: widget1,
                      dimension: 100,
                    ),
                  ),
                ),
                _MouseRegion(
                  state: regionOuter2,
                  child: _MouseRegion(
                    state: regionInner2,
                    child: const SizedBox.square(
                      key: widget2,
                      dimension: 100,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(regionContainer.isInside, false);
    expect(regionOuter1.isInside, false);
    expect(regionInner1.isInside, false);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    for (int i = 0; i < 2; ++i) {
      // hover first, then down
      await gesture.moveTo(tester.getCenter(find.byKey(widget1)));
      await gesture.down(tester.getCenter(find.byKey(widget1)));

      expect(regionContainer.isInside, true);
      expect(regionOuter1.isInside, true);
      expect(regionInner1.isInside, true);
      expect(regionOuter2.isInside, false);
      expect(regionInner2.isInside, false);

      // When moving to second while buttons is pressed hover is preserved.
      await gesture.moveTo(tester.getCenter(find.byKey(widget2)));
      expect(regionContainer.isInside, true);
      expect(regionOuter1.isInside, true);
      expect(regionInner1.isInside, true);
      expect(regionOuter2.isInside, false);
      expect(regionInner2.isInside, false);

      await gesture.moveTo(tester.getCenter(find.byKey(widget1)));
      expect(regionContainer.isInside, true);
      expect(regionOuter1.isInside, true);
      expect(regionInner1.isInside, true);
      expect(regionOuter2.isInside, false);
      expect(regionInner2.isInside, false);

      // Second widget again.
      await gesture.moveTo(tester.getCenter(find.byKey(widget2)));
      expect(regionContainer.isInside, true);
      expect(regionOuter1.isInside, true);
      expect(regionInner1.isInside, true);
      expect(regionOuter2.isInside, false);
      expect(regionInner2.isInside, false);

      // Release - should restore hover on second widget.
      await gesture.up();

      // When releasing button there is normally a hover event immediately, but that
      // does not seem to be the case with Widget tester.
      await gesture.moveBy(Offset.zero);
      expect(regionContainer.isInside, true);
      expect(regionOuter1.isInside, false);
      expect(regionInner1.isInside, false);
      expect(regionOuter2.isInside, true);
      expect(regionInner2.isInside, true);
    }
  });

  testWidgetsFakeAsync('scrolling delays event', (tester, async) async {
    final region1 = _MouseRegionState();
    final region2 = _MouseRegionState();

    const widget1 = Key('Widget1');
    const widget2 = Key('Widget2');

    await tester.pumpWidget(TestApp(
      home: SingleChildScrollView(
        child: Column(
          children: [
            _MouseRegion(
              state: region1,
              child: const SizedBox.square(key: widget1, dimension: 100),
            ),
            _MouseRegion(
              state: region2,
              child: const SizedBox.square(key: widget2, dimension: 100),
            ),
            const SizedBox(height: 10000),
          ],
        ),
      ),
    ));

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      pointer.hover(tester.getCenter(find.byKey(widget1))),
    );
    expect(region1.isInside, true);
    expect(region2.isInside, false);

    await tester.sendEventToBinding(
      pointer.scroll(const Offset(0, 100)),
    );
    await tester.pumpAndSettle();
    expect(region1.isInside, true);
    expect(region2.isInside, false);

    async.elapse(const Duration(milliseconds: 50));
    expect(region1.isInside, true);
    expect(region2.isInside, false);

    async.elapse(const Duration(milliseconds: 50));
    expect(region1.isInside, false);
    expect(region2.isInside, true);
  });

  testWidgetsFakeAsync('scrolling timer restarts', (tester, async) async {
    final region1 = _MouseRegionState();
    final region2 = _MouseRegionState();

    const widget1 = Key('Widget1');
    const widget2 = Key('Widget2');

    await tester.pumpWidget(TestApp(
      home: SingleChildScrollView(
        child: Column(
          children: [
            _MouseRegion(
              state: region1,
              child: const SizedBox.square(key: widget1, dimension: 100),
            ),
            _MouseRegion(
              state: region2,
              child: const SizedBox.square(key: widget2, dimension: 100),
            ),
            const SizedBox(height: 10000),
          ],
        ),
      ),
    ));

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      pointer.hover(tester.getCenter(find.byKey(widget1))),
    );
    expect(region1.isInside, true);
    expect(region2.isInside, false);

    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));
    await tester.pumpAndSettle();
    expect(region1.isInside, true);
    expect(region2.isInside, false);

    async.elapse(const Duration(milliseconds: 50));
    expect(region1.isInside, true);
    expect(region2.isInside, false);

    for (int i = 0; i < 5; ++i) {
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 1)));
      await tester.pumpAndSettle();

      async.elapse(const Duration(milliseconds: 50));
      expect(region1.isInside, true);
      expect(region2.isInside, false);

      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 1)));
      await tester.pumpAndSettle();

      async.elapse(const Duration(milliseconds: 50));
      expect(region1.isInside, true);
      expect(region2.isInside, false);
    }

    async.elapse(const Duration(milliseconds: 100));
    expect(region1.isInside, false);
    expect(region2.isInside, true);
  });

  testWidgetsFakeAsync(
    'hover updated on hover event during scrolling',
    (tester, async) async {
      final region1 = _MouseRegionState();
      final region2 = _MouseRegionState();

      const widget1 = Key('Widget1');
      const widget2 = Key('Widget2');

      await tester.pumpWidget(TestApp(
        home: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 200),
              _MouseRegion(
                state: region1,
                child: const SizedBox.square(key: widget1, dimension: 100),
              ),
              _MouseRegion(
                state: region2,
                child: const SizedBox.square(key: widget2, dimension: 100),
              ),
              const SizedBox(height: 10000),
            ],
          ),
        ),
      ));

      final pointerHover = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        pointerHover.hover(tester.getCenter(find.byKey(widget1))),
      );

      final pointer = TestPointer(2, PointerDeviceKind.trackpad);
      await tester.sendEventToBinding(
        pointer.panZoomStart(tester.getCenter(find.byKey(widget1))),
      );
      await tester.sendEventToBinding(
        pointer.panZoomUpdate(
          tester.getCenter(find.byKey(widget1)),
          pan: const Offset(0, -20),
          timeStamp: const Duration(milliseconds: 10),
        ),
      );
      await tester.sendEventToBinding(
        pointer.panZoomUpdate(
          tester.getCenter(find.byKey(widget1)),
          pan: const Offset(0, -40),
          timeStamp: const Duration(milliseconds: 14),
        ),
      );

      await tester.sendEventToBinding(pointer.panZoomEnd());

      // Start scrolling
      await tester.pump(const Duration(milliseconds: 10));

      expect(region1.isInside, true);
      expect(region2.isInside, false);

      // This should not be ignored.
      await tester.sendEventToBinding(
        pointerHover.hover(tester.getCenter(find.byKey(widget2))),
      );

      await tester.pump(const Duration(milliseconds: 50));

      expect(region1.isInside, false);
      expect(region2.isInside, true);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}
