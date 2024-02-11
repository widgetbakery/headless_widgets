import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headless_widgets/headless_widgets.dart';

class TestMultiChildLayoutDelegate extends SizedMultiChildLayoutDelegate {
  BoxConstraints? performLayoutConstraints;
  late Size performLayoutSize0;
  late Size performLayoutSize1;
  late bool performLayoutIsChild;

  @override
  Size performLayout(BoxConstraints layoutConstraints) {
    const size = Size(200.0, 300.0);
    expect(() {
      performLayoutConstraints = layoutConstraints;
      final BoxConstraints constraints = BoxConstraints.loose(size);
      performLayoutSize0 = layoutChild(0, constraints);
      performLayoutSize1 = layoutChild(1, constraints);
      positionChild(0, Offset.zero);
      positionChild(1, Offset.zero);
      performLayoutIsChild = hasChild('fred');
    }, returnsNormally);
    return size;
  }

  bool shouldRelayoutCalled = false;
  bool shouldRelayoutValue = false;

  @override
  bool shouldRelayout(_) {
    assert(!RenderObject.debugCheckingIntrinsics);
    shouldRelayoutCalled = true;
    return shouldRelayoutValue;
  }
}

Widget buildFrame(SizedMultiChildLayoutDelegate delegate) {
  return Center(
    child: SizedCustomMultiChildLayout(
      delegate: delegate,
      children: <Widget>[
        LayoutId(id: 0, child: const SizedBox(width: 150.0, height: 100.0)),
        LayoutId(id: 1, child: const SizedBox(width: 100.0, height: 200.0)),
      ],
    ),
  );
}

class PreferredSizeDelegate extends SizedMultiChildLayoutDelegate {
  PreferredSizeDelegate({required this.preferredSize});

  final Size preferredSize;

  @override
  Size performLayout(BoxConstraints constraints) {
    return preferredSize;
  }

  @override
  bool shouldRelayout(PreferredSizeDelegate oldDelegate) {
    return preferredSize != oldDelegate.preferredSize;
  }
}

class NotifierLayoutDelegate extends SizedMultiChildLayoutDelegate {
  NotifierLayoutDelegate(this.size) : super(relayout: size);

  final ValueNotifier<Size> size;

  @override
  Size performLayout(BoxConstraints constraints) {
    return size.value;
  }

  @override
  bool shouldRelayout(NotifierLayoutDelegate oldDelegate) {
    return size != oldDelegate.size;
  }
}

// LayoutDelegate that lays out child with id 0 and 1
// Used in the 'performLayout error control test' test case to trigger:
//  - error when laying out a non existent child and a child that has not been laid out
class ZeroAndOneIdLayoutDelegate extends SizedMultiChildLayoutDelegate {
  @override
  Size performLayout(BoxConstraints constraints) {
    constraints = constraints.loosen();
    layoutChild(0, constraints);
    layoutChild(1, constraints);
    return constraints.biggest;
  }

  @override
  bool shouldRelayout(SizedMultiChildLayoutDelegate oldDelegate) => true;
}

// Used in the 'performLayout error control test' test case for triggering
//  to layout child more than once
class InvalidConstraintsChildLayoutDelegate
    extends SizedMultiChildLayoutDelegate {
  @override
  Size performLayout(BoxConstraints constraints) {
    final BoxConstraints childConstraints = BoxConstraints.loose(
      // Invalid because width and height must be greater than or equal to 0
      const Size(-1, -1),
    );
    layoutChild(0, childConstraints);
    return constraints.biggest;
  }

  @override
  bool shouldRelayout(SizedMultiChildLayoutDelegate oldDelegate) => true;
}

class LayoutWithMissingId extends ParentDataWidget<MultiChildLayoutParentData> {
  const LayoutWithMissingId({
    super.key,
    required super.child,
  });

  @override
  void applyParentData(RenderObject renderObject) {}

  @override
  Type get debugTypicalAncestorWidgetClass => CustomMultiChildLayout;
}

void main() {
  testWidgets('Control test for SizedCustomMultiChildLayout',
      (WidgetTester tester) async {
    final TestMultiChildLayoutDelegate delegate =
        TestMultiChildLayoutDelegate();

    await tester.pumpWidget(buildFrame(delegate));

    expect(delegate.performLayoutConstraints?.minWidth, 0.0);
    expect(delegate.performLayoutConstraints?.maxWidth, 800.0);
    expect(delegate.performLayoutConstraints?.minHeight, 0.0);
    expect(delegate.performLayoutConstraints?.maxHeight, 600.0);

    final RenderBox box = tester.renderObject(
      find.byType(SizedCustomMultiChildLayout),
    );
    expect(box.size.width, 200.0);
    expect(box.size.height, 300.0);

    expect(delegate.performLayoutSize0.width, 150.0);
    expect(delegate.performLayoutSize0.height, 100.0);
    expect(delegate.performLayoutSize1.width, 100.0);
    expect(delegate.performLayoutSize1.height, 200.0);
    expect(delegate.performLayoutIsChild, false);
  });

  testWidgets('Test SizedCustomMultiChildLayout shouldRelayout method',
      (WidgetTester tester) async {
    TestMultiChildLayoutDelegate delegate = TestMultiChildLayoutDelegate();
    await tester.pumpWidget(buildFrame(delegate));

    // Layout happened because the delegate was set.
    expect(
      delegate.performLayoutConstraints,
      isNotNull,
    ); // i.e. layout happened
    expect(delegate.shouldRelayoutCalled, isFalse);

    // Layout did not happen because shouldRelayout() returned false.
    delegate = TestMultiChildLayoutDelegate();
    delegate.shouldRelayoutValue = false;
    await tester.pumpWidget(buildFrame(delegate));
    expect(delegate.shouldRelayoutCalled, isTrue);
    expect(delegate.performLayoutConstraints, isNull);

    // Layout happened because shouldRelayout() returned true.
    delegate = TestMultiChildLayoutDelegate();
    delegate.shouldRelayoutValue = true;
    await tester.pumpWidget(buildFrame(delegate));
    expect(delegate.shouldRelayoutCalled, isTrue);
    expect(delegate.performLayoutConstraints, isNotNull);
  });

  testWidgets('Nested CustomMultiChildLayouts', (WidgetTester tester) async {
    final TestMultiChildLayoutDelegate delegate =
        TestMultiChildLayoutDelegate();
    await tester.pumpWidget(Center(
      child: SizedCustomMultiChildLayout(
        delegate: delegate,
        children: <Widget>[
          LayoutId(
            id: 0,
            child: SizedCustomMultiChildLayout(
              delegate: delegate,
              children: <Widget>[
                LayoutId(
                  id: 0,
                  child: const SizedBox(width: 150.0, height: 100.0),
                ),
                LayoutId(
                  id: 1,
                  child: const SizedBox(width: 100.0, height: 200.0),
                ),
              ],
            ),
          ),
          LayoutId(
            id: 1,
            child: const SizedBox(width: 100.0, height: 200.0),
          ),
        ],
      ),
    ));
  });

  testWidgets('Loose constraints', (WidgetTester tester) async {
    final Key key = UniqueKey();
    await tester.pumpWidget(Center(
      child: SizedCustomMultiChildLayout(
        key: key,
        delegate: PreferredSizeDelegate(
          preferredSize: const Size(300.0, 200.0),
        ),
      ),
    ));

    final RenderBox box = tester.renderObject(find.byKey(key));
    expect(box.size.width, equals(300.0));
    expect(box.size.height, equals(200.0));

    await tester.pumpWidget(Center(
      child: SizedCustomMultiChildLayout(
        key: key,
        delegate: PreferredSizeDelegate(
          preferredSize: const Size(350.0, 250.0),
        ),
      ),
    ));

    expect(box.size.width, equals(350.0));
    expect(box.size.height, equals(250.0));
  });

  testWidgets('Can use listener for relayout', (WidgetTester tester) async {
    final ValueNotifier<Size> size =
        ValueNotifier<Size>(const Size(100.0, 200.0));
    addTearDown(size.dispose);

    await tester.pumpWidget(
      Center(
        child: SizedCustomMultiChildLayout(
          delegate: NotifierLayoutDelegate(size),
        ),
      ),
    );

    RenderBox box = tester.renderObject(
      find.byType(SizedCustomMultiChildLayout),
    );
    expect(box.size, equals(const Size(100.0, 200.0)));

    size.value = const Size(150.0, 240.0);
    await tester.pump();

    box = tester.renderObject(find.byType(SizedCustomMultiChildLayout));
    expect(box.size, equals(const Size(150.0, 240.0)));
  });

  group('performLayout error control test', () {
    Widget buildSingleChildFrame(SizedMultiChildLayoutDelegate delegate) {
      return Center(
        child: SizedCustomMultiChildLayout(
          delegate: delegate,
          children: <Widget>[LayoutId(id: 0, child: const SizedBox())],
        ),
      );
    }

    Future<void> expectFlutterErrorMessage({
      Widget? widget,
      SizedMultiChildLayoutDelegate? delegate,
      required WidgetTester tester,
      required String message,
    }) async {
      final FlutterExceptionHandler? oldHandler = FlutterError.onError;
      final List<FlutterErrorDetails> errors = <FlutterErrorDetails>[];
      FlutterError.onError = (FlutterErrorDetails error) => errors.add(error);
      try {
        await tester.pumpWidget(widget ?? buildSingleChildFrame(delegate!));
      } finally {
        FlutterError.onError = oldHandler;
      }
      expect(errors.length, isNonZero);
      expect(errors.first, isNotNull);
      expect(errors.first.exception, isFlutterError);
      expect((errors.first.exception as FlutterError).toStringDeep(),
          equalsIgnoringHashCodes(message));
    }

    testWidgets('layoutChild on non existent child',
        (WidgetTester tester) async {
      await expectFlutterErrorMessage(
        tester: tester,
        delegate: ZeroAndOneIdLayoutDelegate(),
        message: 'FlutterError\n'
            '   The ZeroAndOneIdLayoutDelegate custom multichild layout delegate\n'
            '   tried to lay out a non-existent child.\n'
            '   There is no child with the id "1".\n',
      );
    });

    testWidgets('layoutChild on invalid size constraint',
        (WidgetTester tester) async {
      await expectFlutterErrorMessage(
        tester: tester,
        delegate: InvalidConstraintsChildLayoutDelegate(),
        message: 'FlutterError\n'
            '   The InvalidConstraintsChildLayoutDelegate custom multichild\n'
            '   layout delegate provided invalid box constraints for the child\n'
            '   with id "0".\n'
            '   FlutterError\n'
            '   The minimum width and height must be greater than or equal to\n'
            '   zero.\n'
            '   The maximum width must be greater than or equal to the minimum\n'
            '   width.\n'
            '   The maximum height must be greater than or equal to the minimum\n'
            '   height.\n',
      );
    });

    testWidgets("_callPerformLayout on child that doesn't have id",
        (WidgetTester tester) async {
      await expectFlutterErrorMessage(
        widget: Center(
          child: SizedCustomMultiChildLayout(
            delegate: PreferredSizeDelegate(preferredSize: const Size(10, 10)),
            children: <Widget>[
              LayoutWithMissingId(child: Container(width: 100))
            ],
          ),
        ),
        tester: tester,
        message: 'FlutterError\n'
            '   Every child of a RenderSizedCustomMultiChildLayoutBox must have\n'
            '   an ID in its parent data.\n'
            '   The following child has no ID: RenderConstrainedBox#00000 NEEDS-LAYOUT NEEDS-PAINT:\n'
            '     creator: ConstrainedBox ← Container ← LayoutWithMissingId ←\n'
            '       SizedCustomMultiChildLayout ← Center ← MediaQuery ←\n'
            '       _MediaQueryFromView ← _PipelineOwnerScope ← _ViewScope ←\n'
            '       _RawView-[_DeprecatedRawViewKey TestFlutterView#00000] ← View ←\n'
            '       [root]\n'
            '     parentData: offset=Offset(0.0, 0.0); id=null\n'
            '     constraints: MISSING\n'
            '     size: MISSING\n'
            '     additionalConstraints: BoxConstraints(w=100.0, 0.0<=h<=Infinity)\n',
      );
    });

    testWidgets('performLayout did not layout a child',
        (WidgetTester tester) async {
      await expectFlutterErrorMessage(
        widget: Center(
          child: SizedCustomMultiChildLayout(
            delegate: ZeroAndOneIdLayoutDelegate(),
            children: <Widget>[
              LayoutId(id: 0, child: Container(width: 100)),
              LayoutId(id: 1, child: Container(width: 100)),
              LayoutId(id: 2, child: Container(width: 100)),
            ],
          ),
        ),
        tester: tester,
        message: 'FlutterError\n'
            '   Each child must be laid out at least once.\n'
            '   The ZeroAndOneIdLayoutDelegate custom multichild layout delegate'
            ' forgot to lay out the following child:\n'
            '     2: RenderConstrainedBox#62a34 NEEDS-LAYOUT NEEDS-PAINT\n',
      );
    });

    testWidgets('performLayout did not layout multiple child',
        (WidgetTester tester) async {
      await expectFlutterErrorMessage(
        widget: Center(
          child: SizedCustomMultiChildLayout(
            delegate: ZeroAndOneIdLayoutDelegate(),
            children: <Widget>[
              LayoutId(id: 0, child: Container(width: 100)),
              LayoutId(id: 1, child: Container(width: 100)),
              LayoutId(id: 2, child: Container(width: 100)),
              LayoutId(id: 3, child: Container(width: 100)),
            ],
          ),
        ),
        tester: tester,
        message: 'FlutterError\n'
            '   Each child must be laid out at least once.\n'
            '   The ZeroAndOneIdLayoutDelegate custom multichild layout delegate'
            ' forgot to lay out the following children:\n'
            '     2: RenderConstrainedBox#62a34 NEEDS-LAYOUT NEEDS-PAINT\n'
            '     3: RenderConstrainedBox#62a34 NEEDS-LAYOUT NEEDS-PAINT\n',
      );
    });
    testWidgets('performLayout did not position multiple children',
        (WidgetTester tester) async {
      await expectFlutterErrorMessage(
        widget: Center(
          child: SizedCustomMultiChildLayout(
            delegate: ZeroAndOneIdLayoutDelegate(),
            children: <Widget>[
              LayoutId(id: 0, child: Container(width: 100)),
              LayoutId(id: 1, child: Container(width: 100)),
            ],
          ),
        ),
        tester: tester,
        message: 'FlutterError\n'
            '   Each child must be positioned at least once.\n'
            '   The ZeroAndOneIdLayoutDelegate custom multichild layout delegate'
            ' forgot to position the following children:\n'
            '     0: RenderConstrainedBox#62a34 relayoutBoundary=up2\n'
            '     1: RenderConstrainedBox#62a34 relayoutBoundary=up2\n',
      );
    });
  });
}
