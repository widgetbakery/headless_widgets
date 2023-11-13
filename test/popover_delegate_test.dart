import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headless/headless.dart';

import 'test_util.dart';

class TestDelegate extends BasePopoverDelegate {
  TestDelegate({
    required super.attachments,
    required super.calloutSize,
    required super.popoverDistance,
    required super.calloutAnimationDuration,
  });

  ValueNotifier<PopoverGeometry?>? _geometry;

  PopoverGeometry? get lastGeometry => _geometry?.value;

  @override
  Widget buildPopover(
      BuildContext context,
      Widget child,
      Animation<double> animation,
      ValueNotifier<PopoverGeometry?> geometry,
      double Function(bool calloutVisible) calloutHeightFactor) {
    _geometry = geometry;
    return child;
  }

  @override
  Widget buildVeil(
    BuildContext context,
    Animation<double> animation,
    VoidCallback dismissPopover,
  ) {
    return const SizedBox.shrink();
  }
}

class PopoverWidget extends StatefulWidget {
  const PopoverWidget({
    super.key,
    required this.attachments,
    required this.child,
  });

  final Widget child;
  final List<PopoverAttachment> attachments;

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
      delegate: () => _currentDelegate = TestDelegate(
        attachments: widget.attachments,
        calloutSize: 0,
        popoverDistance: 0,
        calloutAnimationDuration: Duration.zero,
      ),
      child: widget.child,
    );
  }
}

void main() {
  testWidgets('PopoverDelegate choses correct attachment and preserves it', (tester) async {
    final key = GlobalKey<_PopoverWidgetState>();

    Future<void> pumpWidget(double x, double y) async {
      await tester.pumpWidget(
        TestApp(
          home: Stack(
            children: [
              Positioned(
                top: y,
                left: x,
                child: PopoverWidget(
                  attachments: const [
                    PopoverAttachment(
                      anchor: Alignment.bottomCenter,
                      popover: Alignment.topCenter,
                    ),
                    PopoverAttachment(
                      anchor: Alignment.topCenter,
                      popover: Alignment.bottomCenter,
                    )
                  ],
                  key: key,
                  child: const SizedBox(width: 100, height: 100),
                ),
              ),
            ],
          ),
        ),
      );
    }

    await pumpWidget(0, 400);
    key.currentState!._controller.showPopover(const SizedBox(width: 400, height: 400));
    await tester.pumpAndSettle();

    final delegate = key.currentState!._currentDelegate!;

    expect(
      delegate.lastGeometry!.attachment,
      const PopoverAttachment(
        anchor: Alignment.topCenter,
        popover: Alignment.bottomCenter,
      ),
    );
    expect(
      delegate.lastGeometry!.anchor,
      const Rect.fromLTWH(0, 400, 100, 100),
    );
    expect(
      delegate.lastGeometry!.popover,
      const Rect.fromLTWH(0, 0, 400, 400),
    );

    // Moving anchor all the way up should preserve attachment but the
    // relative position of anchor and popover should change.
    await pumpWidget(0, 0);
    await tester.pumpAndSettle();

    expect(
      delegate.lastGeometry!.attachment,
      const PopoverAttachment(
        anchor: Alignment.topCenter,
        popover: Alignment.bottomCenter,
      ),
    );
    expect(
      delegate.lastGeometry!.anchor,
      const Rect.fromLTWH(0, 0, 100, 100),
    );
    expect(
      delegate.lastGeometry!.popover,
      const Rect.fromLTWH(0, 0, 400, 400),
    );
  });
}
