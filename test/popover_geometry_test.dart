import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headless/headless.dart';

void main() {
  group('PopoverAttachment', () {
    test('getCalloutEdge returns correct PopoverEdge', () {
      expect(
        const PopoverAttachment(
          anchor: Alignment.bottomCenter,
          popover: Alignment.topCenter,
        ).getCalloutEdge(),
        equals(PopoverEdge.top),
      );
      expect(
        const PopoverAttachment(
          anchor: Alignment.bottomLeft,
          popover: Alignment.topRight,
        ).getCalloutEdge(),
        equals(PopoverEdge.top),
      );
      expect(
        const PopoverAttachment(
          anchor: Alignment.topCenter,
          popover: Alignment.bottomCenter,
        ).getCalloutEdge(),
        equals(PopoverEdge.bottom),
      );
      expect(
        const PopoverAttachment(
          anchor: Alignment.topLeft,
          popover: Alignment.bottomRight,
        ).getCalloutEdge(),
        equals(PopoverEdge.bottom),
      );
      expect(
        const PopoverAttachment(
          anchor: Alignment.centerRight,
          popover: Alignment.centerLeft,
        ).getCalloutEdge(),
        equals(PopoverEdge.left),
      );
      expect(
        const PopoverAttachment(
          anchor: Alignment.bottomRight,
          popover: Alignment.bottomLeft,
        ).getCalloutEdge(),
        equals(PopoverEdge.left),
      );
      expect(
        const PopoverAttachment(
          anchor: Alignment.centerLeft,
          popover: Alignment.centerRight,
        ).getCalloutEdge(),
        equals(PopoverEdge.right),
      );
      expect(
        const PopoverAttachment(
          anchor: Alignment.topLeft,
          popover: Alignment.topRight,
        ).getCalloutEdge(),
        equals(PopoverEdge.right),
      );
    });

    test('getCalloutEdge returns null overlapping alignment', () {
      expect(
        const PopoverAttachment(
          anchor: Alignment.topCenter,
          popover: Alignment.topCenter,
        ).getCalloutEdge(),
        isNull,
      );
      expect(
        const PopoverAttachment(
          anchor: Alignment.topLeft,
          popover: Alignment.topLeft,
        ).getCalloutEdge(),
        isNull,
      );
      expect(
        const PopoverAttachment(
          anchor: Alignment.bottomRight,
          popover: Alignment.bottomRight,
        ).getCalloutEdge(),
        isNull,
      );
    });

    test('getPopoverOffset returns correct Offset', () {
      {
        const attachment = PopoverAttachment(
          anchor: Alignment.topRight,
          popover: Alignment.centerLeft,
        );
        final offset = attachment.getPopoverOffset(
          const Rect.fromLTWH(10, 10, 20, 20),
          const Size(50, 50),
          20,
        );
        expect(offset, equals(const Offset(50, -15)));
      }
      {
        const attachment = PopoverAttachment(
          anchor: Alignment.topLeft,
          popover: Alignment.topRight,
        );
        final offset = attachment.getPopoverOffset(
          const Rect.fromLTWH(10, 10, 20, 20),
          const Size(40, 40),
          20,
        );
        expect(offset, equals(const Offset(-50, 10)));
      }
      {
        const attachment = PopoverAttachment(
          anchor: Alignment.bottomCenter,
          popover: Alignment.topCenter,
        );
        final offset = attachment.getPopoverOffset(
          const Rect.fromLTWH(10, 10, 20, 20),
          const Size(40, 40),
          10,
        );
        expect(offset, equals(const Offset(0, 40)));
      }
      {
        const attachment = PopoverAttachment(
          anchor: Alignment.bottomCenter,
          popover: Alignment.topCenter,
        );
        final offset = attachment.getPopoverOffset(
          const Rect.fromLTWH(10, 10, 20, 20),
          const Size(40, 40),
          10,
        );
        expect(offset, equals(const Offset(0, 40)));
      }
      {
        const attachment = PopoverAttachment(
          anchor: Alignment.bottomCenter,
          popover: Alignment.topCenter,
        );
        final offset = attachment.getPopoverOffset(
          const Rect.fromLTWH(10, 10, 20, 20),
          const Size(40, 40),
          10,
        );
        expect(offset, equals(const Offset(0, 40)));
      }
      {
        const attachment = PopoverAttachment(
          anchor: Alignment.bottomRight,
          popover: Alignment.bottomRight,
        );
        final offset = attachment.getPopoverOffset(
          const Rect.fromLTWH(10, 10, 30, 30),
          const Size(20, 20),
          20,
        );
        // Overlapping - distance is not applied.
        expect(offset, equals(const Offset(20, 20)));
      }
    });
  });

  group('PopoverGeometry', () {
    test('getAlignment returns correct Alignment', () {
      const geometry = PopoverGeometry(
        attachment: PopoverAttachment(anchor: Alignment.center, popover: Alignment.center),
        requestedDistance: 10.0,
        anchor: Rect.fromLTWH(0, 0, 50, 50),
        popover: Rect.fromLTWH(0, 60, 100, 100),
        popoverWidgetInsets: EdgeInsets.all(5),
        calloutSize: 5.0,
      );
      final alignment = geometry.getAlignment();
      expect(alignment, equals(const Alignment(-0.5, -1.0)));
    });
  });
}
