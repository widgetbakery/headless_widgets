import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headless/headless.dart';

import 'test_util.dart';

enum _DelegateCall {
  buildScaffold,
  computePosition,
}

class TestDelegate extends PopoverDelegate {
  final calls = <_DelegateCall>[];

  @override
  Widget buildScaffold(BuildContext context, Widget child, Animation<double> animation) {
    calls.add(_DelegateCall.buildScaffold);
    return child;
  }

  @override
  Widget buildVeil(BuildContext context, Animation<double> animation, VoidCallback dismissPopover) {
    return Container();
  }

  @override
  BoxConstraints computeConstraints(Rect bounds, EdgeInsets safeAreaInsets, Rect anchor) {
    return BoxConstraints.loose(safeAreaInsets.deflateRect(bounds).size);
  }

  @override
  Offset computePosition(Rect bounds, EdgeInsets safeAreaInsets, Rect anchor, Size popoverSize) {
    calls.add(_DelegateCall.computePosition);
    return anchor.bottomLeft;
  }
}

class PopoverWidget extends StatefulWidget {
  const PopoverWidget({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<StatefulWidget> createState() => _PopoverWidgetState();
}

class _PopoverWidgetState extends State<PopoverWidget> {
  final _controller = PopoverController();

  TestDelegate? _currentDelegate;

  @override
  Widget build(BuildContext context) {
    return PopoverAnchor(
      controller: _controller,
      delegate: () => _currentDelegate = TestDelegate(),
      child: widget.child,
    );
  }
}

void main() {
  testWidgets('show / hide works', (tester) async {
    final key = GlobalKey<_PopoverWidgetState>();
    await tester.pumpWidget(
      TestApp(
        home: PopoverWidget(
          key: key,
          child: const Text('Anchor'),
        ),
      ),
    );
    expect(find.text('Anchor'), findsOneWidget);
    bool hidden = false;
    key.currentState!._controller.showPopover(const Text('Popover')).then((_) {
      hidden = true;
    });
    await tester.pumpAndSettle();
    expect(find.text('Popover'), findsOneWidget);
    expect(hidden, isFalse);

    key.currentState!._controller.hidePopover();
    await tester.pumpAndSettle();
    expect(find.text('Popover'), findsNothing);
    expect(hidden, isTrue);
  });

  testWidgets('replacing popover', (tester) async {
    final key = GlobalKey<_PopoverWidgetState>();
    await tester.pumpWidget(
      TestApp(
        home: PopoverWidget(
          key: key,
          child: const Text('Anchor'),
        ),
      ),
    );

    bool hidden1 = false;
    bool hidden2 = false;
    key.currentState!._controller.showPopover(const Text('Popover1')).then((_) {
      hidden1 = true;
    });
    await tester.pumpAndSettle();
    expect(find.text('Popover1'), findsOneWidget);

    key.currentState!._controller.showPopover(const Text('Popover2')).then((_) {
      hidden2 = true;
    });

    await tester.pump();

    expect(find.text('Popover2'), findsOneWidget);
    expect(find.text('Popover1'), findsNothing);

    expect(hidden1, isFalse);
    expect(hidden2, isFalse);

    key.currentState!._controller.hidePopover();
    await tester.pumpAndSettle();
    expect(find.text('Popover2'), findsNothing);

    // Both futures only be completed now.
    expect(hidden1, isTrue);
    expect(hidden2, isTrue);
  });

  testWidgets('removing popover from hierarchy', (tester) async {
    final key = GlobalKey<_PopoverWidgetState>();
    await tester.pumpWidget(
      TestApp(
        home: PopoverWidget(key: key, child: const Text('Anchor')),
      ),
    );

    bool hidden = false;
    key.currentState!._controller.showPopover(const Text('Popover')).then((_) {
      hidden = true;
    });
    await tester.pumpAndSettle();
    expect(find.text('Popover'), findsOneWidget);

    await tester.pumpWidget(const TestApp(home: SizedBox.shrink()));

    expect(find.text('Popover'), findsNothing);
    expect(hidden, isTrue);
  });

  testWidgets('popover follows attachment', (tester) async {
    final key = GlobalKey<_PopoverWidgetState>();
    const popoverKey = ValueKey('popover');

    final popoverWidget = PopoverWidget(
      key: key,
      child: Container(),
    );

    await tester.pumpWidget(
      TestApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(50),
            child: SizedBox(
              width: 40,
              height: 40,
              child: popoverWidget,
            ),
          ),
        ),
      ),
    );
    key.currentState!._controller.showPopover(
      const SizedBox(key: popoverKey, width: 80, height: 30),
    );
    await tester.pump();

    expect(key.currentState!._currentDelegate!.calls, [
      _DelegateCall.buildScaffold,
      _DelegateCall.computePosition,
    ]);

    await tester.pump();

    expect(key.currentState!._currentDelegate!.calls, [
      _DelegateCall.buildScaffold,
      _DelegateCall.computePosition,
      _DelegateCall.buildScaffold, // second build scaffold, now after position
      _DelegateCall.computePosition,
    ]);

    await tester.pump();

    {
      final anchorRect = tester.getRect(find.byKey(key));
      expect(anchorRect, const Rect.fromLTWH(50, 50, 40, 40));
      final popoverRect = tester.getRect(find.byKey(popoverKey));
      expect(popoverRect, const Rect.fromLTWH(50, 90, 80, 30));
    }

    // Increase padding and slightly resize anchor.
    await tester.pumpWidget(
      TestApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 70),
            child: SizedBox(
              width: 40,
              height: 45,
              child: popoverWidget,
            ),
          ),
        ),
      ),
    );

    expect(key.currentState!._currentDelegate!.calls, [
      _DelegateCall.buildScaffold,
      _DelegateCall.computePosition,
      _DelegateCall.buildScaffold,
      _DelegateCall.computePosition,
      _DelegateCall.computePosition, // no build need, only relayout.
    ]);

    final anchorRect = tester.getRect(find.byKey(key));
    expect(anchorRect, const Rect.fromLTWH(60, 70, 40, 45));
    final popoverRect = tester.getRect(find.byKey(popoverKey));
    expect(popoverRect, const Rect.fromLTWH(60, 115, 80, 30));
  });

  testWidgets('popover anchor in transform', (tester) async {
    final key = GlobalKey<_PopoverWidgetState>();
    const popoverKey = ValueKey('popover');

    final popoverWidget = PopoverWidget(
      key: key,
      child: Container(),
    );

    await tester.pumpWidget(
      TestApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: Transform.scale(
            scale: 1.5,
            child: SizedBox(
              width: 40,
              height: 40,
              child: popoverWidget,
            ),
          ),
        ),
      ),
    );

    key.currentState!._controller.showPopover(
      const SizedBox(key: popoverKey, width: 80, height: 30),
    );
    await tester.pump();

    final anchorRect = tester.getRect(find.byKey(key));
    expect(
      anchorRect,
      const Rect.fromLTWH(-10, -10, 60, 60),
    );

    final popoverRect = tester.getRect(find.byKey(popoverKey));
    expect(
      popoverRect,
      const Rect.fromLTWH(-10, 50, 80, 30),
    );
  });

  testWidgets('application widget not filling entire screen', (tester) async {
    final key = GlobalKey<_PopoverWidgetState>();
    const popoverKey = ValueKey('popover');

    final popoverWidget = PopoverWidget(
      key: key,
      child: Container(),
    );

    await tester.pumpWidget(
      Column(
        children: [
          const SizedBox(height: 20),
          Expanded(
            child: TestApp(
              home: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(50),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: popoverWidget,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    key.currentState!._controller.showPopover(
      const SizedBox(key: popoverKey, width: 80, height: 30),
    );
    await tester.pump();

    final anchorRect = tester.getRect(find.byKey(key));
    expect(anchorRect, const Rect.fromLTWH(50, 70, 40, 40));

    final popoverRect = tester.getRect(find.byKey(popoverKey));
    expect(popoverRect, const Rect.fromLTWH(50, 110, 80, 30));
  });
}
