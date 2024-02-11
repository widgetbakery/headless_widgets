import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Typography;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';

typedef TesterFakeAsyncCallback = Future<void> Function(
  WidgetTester widgetTester,
  FakeAsync async,
);

@isTest
void testWidgetsFakeAsync(
  String description,
  TesterFakeAsyncCallback callback, {
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgets(
    description,
    (WidgetTester tester) async {
      final async = FakeAsync();
      async.run((async) async {
        await callback(tester, async);
      });
      async.flushMicrotasks();
    },
    variant: variant,
  );
}

bool get isMouse =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.linux ||
    defaultTargetPlatform == TargetPlatform.windows;

bool get isTouch => !isMouse;

extension PlatformGesture on WidgetTester {
  Future<TestGesture> createPlatformGesture({
    required Offset initialLocation,
  }) async {
    final gesture = await createGesture(
      kind: isMouse ? PointerDeviceKind.mouse : PointerDeviceKind.touch,
    );
    await gesture.addPointer(location: initialLocation);
    addTearDown(gesture.removePointer);
    return gesture;
  }
}

class TestApp extends StatelessWidget {
  const TestApp({super.key, required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    final res = WidgetsApp(
      color: const Color(0x00000000),
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
        return PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (context, _, __) => builder(context));
      },
      home: DefaultTextStyle(
        style: Typography.material2018(platform: defaultTargetPlatform)
            .englishLike
            .bodyMedium!,
        child: home,
      ),
    );
    return res;
  }
}
