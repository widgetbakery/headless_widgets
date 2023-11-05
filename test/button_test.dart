import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headless/headless.dart';

import 'test_util.dart';

class _TestButton extends StatelessWidget {
  const _TestButton({
    super.key,
    this.onPressed,
    this.onPressedDown,
    this.pressDownDelay = Duration.zero,
    required this.onStateChanged,
    this.touchExtraTolerance = EdgeInsets.zero,
    this.keyUpTimeout,
  });

  final VoidCallback? onPressed;
  final FutureOr<void> Function()? onPressedDown;
  final ValueChanged<ControlState> onStateChanged;
  final Duration pressDownDelay;
  final EdgeInsets touchExtraTolerance;
  final Duration? keyUpTimeout;

  @override
  Widget build(BuildContext context) {
    return Button(
      hitTestBehavior: HitTestBehavior.opaque,
      onPressed: onPressed,
      onPressedDown: onPressedDown,
      pressDownDelay: pressDownDelay,
      keyUpTimeout: keyUpTimeout,
      builder: (context, controlState, child) {
        onStateChanged(controlState);
        return const SizedBox.square(
          dimension: 100,
        );
      },
      touchExtraTolerance: touchExtraTolerance,
    );
  }
}

void main() {
  group('pointer', () {
    testWidgets(
      'onPressed works',
      (tester) async {
        const button = ValueKey('button');
        bool pressed;
        late ControlState state;
        await tester.pumpWidget(
          Center(
            child: _TestButton(
              key: button,
              onPressed: () {
                pressed = true;
              },
              onStateChanged: (s) {
                state = s;
              },
            ),
          ),
        );

        final gesture = await tester.createPlatformGesture(initialLocation: Offset.zero);

        for (int i = 0; i < 2; ++i) {
          pressed = false;

          await gesture.moveTo(Offset.zero);
          await tester.pump();

          expect(state, ControlState(enabled: true));

          await gesture.down(tester.getCenter(find.byKey(button)));
          await tester.pump();

          expect(
            state,
            ControlState(enabled: true, tracked: true, pressed: true),
          );
          expect(pressed, isFalse);

          await gesture.up();
          await tester.pump();

          expect(state, ControlState(enabled: true, hovered: isMouse));
          expect(pressed, isTrue);
        }
      },
      variant: const TargetPlatformVariant(
        {TargetPlatform.macOS, TargetPlatform.iOS},
      ),
    );

    testWidgets(
      'does not call onPressed when calling onPressedDown',
      (tester) async {
        const button = ValueKey('button');
        late ControlState state;
        bool pressed;
        bool pressedDown;
        final completer = [Completer<void>()];

        await tester.pumpWidget(
          Center(
            child: _TestButton(
              key: button,
              onPressed: () {
                pressed = true;
              },
              onPressedDown: () {
                pressedDown = true;
                return completer[0].future;
              },
              onStateChanged: (s) {
                state = s;
              },
            ),
          ),
        );

        final gesture = await tester.createPlatformGesture(initialLocation: Offset.zero);

        for (int i = 0; i < 2; ++i) {
          pressedDown = false;
          pressed = false;
          completer[0] = Completer<void>();

          await gesture.down(tester.getCenter(find.byKey(button)));
          await tester.pump();

          expect(
            state,
            ControlState(enabled: true, tracked: true, pressed: true),
          );
          expect(pressedDown, isTrue);

          await gesture.up();
          await tester.pump();

          expect(pressed, isFalse);

          if (i == 0) {
            completer[0].complete();
          } else {
            // Make sure button is in consistent state after future completes with error.
            completer[0].completeError('error');
          }
          await tester.pumpAndSettle(); // required to flush microtasks.

          expect(pressed, isFalse);
          expect(
            state,
            ControlState(enabled: true, hovered: isMouse),
          );
        }
      },
      variant: const TargetPlatformVariant(
        {TargetPlatform.macOS, TargetPlatform.iOS},
      ),
    );

    testWidgets(
      'pressDown works',
      (tester) async {
        const button = ValueKey('button');
        late ControlState state;
        bool pressedDown;
        final completer = [Completer<void>()];

        await tester.pumpWidget(
          Center(
            child: _TestButton(
              key: button,
              onPressedDown: () {
                pressedDown = true;
                return completer[0].future;
              },
              onStateChanged: (s) {
                state = s;
              },
            ),
          ),
        );

        final gesture = await tester.createPlatformGesture(initialLocation: Offset.zero);

        for (int i = 0; i < 2; ++i) {
          pressedDown = false;
          completer[0] = Completer<void>();

          await gesture.down(tester.getCenter(find.byKey(button)));
          await tester.pump();

          expect(
            state,
            ControlState(enabled: true, tracked: true, pressed: true),
          );
          expect(pressedDown, isTrue);

          await gesture.up();
          await tester.pump();

          for (int j = 0; j < 5; ++j) {
            await tester.pump();

            expect(
              state,
              ControlState(enabled: true, hovered: isMouse, pressed: true),
            );
          }

          if (i == 0) {
            completer[0].complete();
          } else {
            // Make sure button is in consistent state after future completes with error.
            completer[0].completeError('error');
          }
          await tester.pumpAndSettle(); // required to flush microtasks.

          expect(
            state,
            ControlState(enabled: true, hovered: isMouse),
          );
        }
      },
      variant: const TargetPlatformVariant(
        {TargetPlatform.macOS, TargetPlatform.iOS},
      ),
    );

    testWidgets(
      'mouse down after onPressedDown completes keeps button pressed',
      (tester) async {
        const button = ValueKey('button');
        late ControlState state;
        bool pressedDown;
        final completer = [Completer<void>()];

        await tester.pumpWidget(
          Center(
            child: _TestButton(
              key: button,
              onPressedDown: () {
                pressedDown = true;
                return completer[0].future;
              },
              onStateChanged: (s) {
                state = s;
              },
            ),
          ),
        );

        final gesture = await tester.createPlatformGesture(initialLocation: Offset.zero);

        for (int i = 0; i < 2; ++i) {
          pressedDown = false;
          completer[0] = Completer<void>();

          await gesture.down(tester.getCenter(find.byKey(button)));
          await tester.pump();

          expect(
            state,
            ControlState(enabled: true, tracked: true, pressed: true),
          );
          expect(pressedDown, isTrue);

          if (i == 0) {
            completer[0].complete();
          } else {
            // Make sure button is in consistent state after future completes with error.
            completer[0].completeError('error');
          }
          await tester.pumpAndSettle(); // required to flush microtasks.

          expect(
            state,
            ControlState(enabled: true, tracked: true, pressed: true),
          );

          await gesture.up();
          await tester.pump();

          expect(
            state,
            ControlState(enabled: true, hovered: isMouse),
          );
        }
      },
      variant: const TargetPlatformVariant(
        {TargetPlatform.macOS, TargetPlatform.iOS},
      ),
    );

    testWidgetsFakeAsync(
      'pressDownDelay works',
      (tester, async) async {
        const button = ValueKey('button');
        late ControlState state;
        bool pressed;
        bool pressedDown;
        final completer = [Completer<void>()];

        await tester.pumpWidget(
          Center(
            child: _TestButton(
              key: button,
              onPressed: () {
                pressed = true;
              },
              pressDownDelay: const Duration(seconds: 1),
              onPressedDown: () {
                pressedDown = true;
                return completer[0].future;
              },
              onStateChanged: (s) {
                state = s;
              },
            ),
          ),
        );

        final gesture = await tester.createPlatformGesture(initialLocation: Offset.zero);

        for (int i = 0; i < 2; ++i) {
          pressed = false;
          pressedDown = false;

          await gesture.down(tester.getCenter(find.byKey(button)));
          await tester.pump();

          expect(
            state,
            ControlState(enabled: true, tracked: true, pressed: true),
          );
          expect(pressedDown, isFalse);

          await Future.delayed(const Duration(milliseconds: 500));
          expect(
            state,
            ControlState(enabled: true, tracked: true, pressed: true),
          );
          expect(pressedDown, isFalse);

          await Future.delayed(const Duration(milliseconds: 500));
          expect(
            state,
            ControlState(enabled: true, hovered: true, pressed: true),
          );
          expect(pressedDown, isTrue);

          await gesture.up();
          await tester.pump();

          completer[0].complete();
          await tester.pumpAndSettle(); // required to flush microtasks.

          expect(
            state,
            ControlState(enabled: true, hovered: isMouse),
          );
          expect(pressed, isFalse);
        }
      },
      variant: const TargetPlatformVariant(
        {TargetPlatform.macOS, TargetPlatform.iOS},
      ),
    );

    testWidgetsFakeAsync(
      'pressDownDelay not reached results in onPressed called',
      (tester, async) async {
        const button = ValueKey('button');
        late ControlState state;
        bool pressed;
        bool pressedDown;
        final completer = [Completer<void>()];

        await tester.pumpWidget(
          Center(
            child: _TestButton(
              key: button,
              onPressed: () {
                pressed = true;
              },
              pressDownDelay: const Duration(seconds: 1),
              onPressedDown: () {
                pressedDown = true;
                return completer[0].future;
              },
              onStateChanged: (s) {
                state = s;
              },
            ),
          ),
        );

        final gesture = await tester.createPlatformGesture(initialLocation: Offset.zero);

        for (int i = 0; i < 2; ++i) {
          pressed = false;
          pressedDown = false;

          await gesture.down(tester.getCenter(find.byKey(button)));
          await tester.pump();

          expect(
            state,
            ControlState(enabled: true, tracked: true, pressed: true),
          );
          expect(pressedDown, isFalse);

          await Future.delayed(const Duration(milliseconds: 500));
          expect(
            state,
            ControlState(enabled: true, tracked: true, pressed: true),
          );
          expect(pressedDown, isFalse);

          // Release before the long press delay.
          await gesture.up();
          await tester.pump();

          expect(
            state,
            ControlState(enabled: true, hovered: isMouse),
          );

          expect(pressed, isTrue);
          expect(pressed, isFalse);

          // Check that the timeout was cancelled.
          await Future.delayed(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();
          expect(pressedDown, isFalse);
        }
      },
      variant: const TargetPlatformVariant(
        {TargetPlatform.macOS, TargetPlatform.iOS},
      ),
    );

    testWidgets(
      'pressed state works correctly when dragging pointer',
      (tester) async {
        const button1 = ValueKey('button1');
        late ControlState state1;
        bool pressed1;

        const button2 = ValueKey('button2');
        late ControlState state2;

        await tester.pumpWidget(
          Center(
            child: Row(
              textDirection: TextDirection.ltr,
              mainAxisSize: MainAxisSize.min,
              children: [
                _TestButton(
                  key: button1,
                  onPressed: () {
                    pressed1 = true;
                  },
                  onStateChanged: (s) {
                    state1 = s;
                  },
                ),
                _TestButton(
                  key: button2,
                  onPressed: () {},
                  onStateChanged: (s) {
                    state2 = s;
                  },
                ),
              ],
            ),
          ),
        );

        final gesture = await tester.createPlatformGesture(initialLocation: Offset.zero);

        for (int i = 0; i < 2; ++i) {
          pressed1 = false;

          await gesture.down(tester.getCenter(find.byKey(button1)));
          await tester.pump();

          expect(
            state1,
            ControlState(enabled: true, tracked: true, pressed: true),
          );
          expect(state2, ControlState(enabled: true));

          // First move accepts the gesture by the recognizer, second is needed to
          // invoke onUpdate callback.
          await gesture.moveTo(tester.getCenter(find.byKey(button2)));
          await gesture.moveBy(const Offset(1, 1));
          await tester.pump();

          // Button 1 gets depressed, but remains tracked.
          expect(state1, ControlState(tracked: true, enabled: true));

          // Button 2 does not get hovered.
          expect(state2, ControlState(enabled: true));

          await gesture.moveTo(tester.getCenter(find.byKey(button1)));
          await tester.pump();

          // Button 1 gets pressed again.
          expect(
            state1,
            ControlState(enabled: true, pressed: true, tracked: true),
          );

          // Button 2 remains same.
          expect(state2, ControlState(enabled: true));

          if (i == 0) {
            // First iteration, release when over button 1.
            await gesture.up();
            await tester.pump();

            expect(state1, ControlState(enabled: true, hovered: isMouse));
            expect(state2, ControlState(enabled: true));
            expect(pressed1, isTrue);
          } else {
            // Second iteration, release when over button 2.
            await gesture.moveTo(tester.getCenter(find.byKey(button2)));
            await tester.pump();
            await gesture.up();
            await tester.pump();

            expect(state1, ControlState(enabled: true));
            expect(state2, ControlState(enabled: true, hovered: isMouse));
            expect(pressed1, isFalse);
          }
        }
      },
      variant: const TargetPlatformVariant(
        {TargetPlatform.macOS, TargetPlatform.iOS},
      ),
    );

    testWidgets(
      'touchExtraTolerance is respected',
      (tester) async {
        const button = ValueKey('button1');
        late ControlState state;
        bool pressed;

        await tester.pumpWidget(
          Center(
            child: _TestButton(
              key: button,
              onPressed: () {
                pressed = true;
              },
              pressDownDelay: const Duration(seconds: 1),
              onStateChanged: (s) {
                state = s;
              },
              touchExtraTolerance: const EdgeInsets.all(20),
            ),
          ),
        );

        final gesture = await tester.createPlatformGesture(initialLocation: Offset.zero);

        final finder = find.byKey(button);

        for (int i = 0; i < 2; ++i) {
          pressed = false;

          await gesture.down(tester.getCenter(finder));
          await tester.pump();

          expect(
            state,
            ControlState(enabled: true, tracked: true, pressed: true),
          );

          await gesture.moveTo(tester.getTopLeft(finder));
          await tester.pump();

          expect(
            state,
            ControlState(enabled: true, tracked: true, pressed: true),
          );

          await gesture.moveBy(const Offset(-10, -10));
          await tester.pump();

          expect(
            state,
            ControlState(enabled: true, tracked: true, pressed: isTouch),
          );

          await gesture.moveBy(const Offset(-11, -11));
          await tester.pump();

          expect(state, ControlState(enabled: true, tracked: true));

          await gesture.moveBy(const Offset(11, 11));
          await tester.pump();

          expect(
            state,
            ControlState(enabled: true, tracked: true, pressed: isTouch),
          );

          await gesture.up();
          await tester.pump();

          expect(
            state,
            ControlState(enabled: true),
          );

          expect(pressed, isTouch);
        }
      },
      variant: const TargetPlatformVariant(
        {TargetPlatform.macOS, TargetPlatform.iOS},
      ),
    );
  });

  group('button group', () {
    testWidgets(
      'sliding works',
      (tester) async {
        const button1 = ValueKey('button1');
        late ControlState state1;
        bool pressed1;

        const button2 = ValueKey('button2');
        late ControlState state2;
        bool pressed2;

        const button3 = ValueKey('button3');
        late ControlState state3;
        bool pressed3;

        await tester.pumpWidget(
          Center(
            child: ButtonGroup(
              allowedDeviceKind: const {PointerDeviceKind.mouse, PointerDeviceKind.touch},
              child: Row(
                textDirection: TextDirection.ltr,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TestButton(
                    key: button1,
                    onPressed: () {
                      pressed1 = true;
                    },
                    onStateChanged: (s) {
                      state1 = s;
                    },
                  ),
                  _TestButton(
                    key: button2,
                    onPressed: () {
                      pressed2 = true;
                    },
                    onStateChanged: (s) {
                      state2 = s;
                    },
                  ),
                  _TestButton(
                    key: button3,
                    onPressed: () {
                      pressed3 = true;
                    },
                    onStateChanged: (s) {
                      state3 = s;
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        final gesture = await tester.createPlatformGesture(initialLocation: Offset.zero);
        for (int i = 0; i < 2; ++i) {
          pressed1 = pressed2 = pressed3 = false;

          await gesture.down(tester.getCenter(find.byKey(button1)));
          await tester.pump();

          expect(
            state1,
            ControlState(enabled: true, tracked: true, pressed: true),
          );
          expect(state2, ControlState(enabled: true));
          expect(state3, ControlState(enabled: true));

          await gesture.moveTo(tester.getCenter(find.byKey(button3)));
          // Needed to invoke onUpdate callback.
          await gesture.moveBy(const Offset(1, 1));
          await tester.pump();

          expect(state1, ControlState(enabled: true));
          expect(state2, ControlState(enabled: true));
          expect(
            state3,
            ControlState(enabled: true, tracked: true, pressed: true),
          );

          await gesture.moveBy(const Offset(0, 200));
          await tester.pump();

          expect(state1, ControlState(enabled: true));
          expect(state2, ControlState(enabled: true));
          expect(
            state3,
            ControlState(enabled: true, tracked: true, pressed: false),
          );

          await gesture.moveTo(tester.getCenter(find.byKey(button2)));
          await tester.pump();

          expect(state1, ControlState(enabled: true));
          expect(
            state2,
            ControlState(enabled: true, tracked: true, pressed: true),
          );
          expect(state3, ControlState(enabled: true));

          await gesture.up();
          await tester.pump();

          expect(state1, ControlState(enabled: true));
          expect(state2, ControlState(enabled: true, hovered: isMouse));
          expect(state3, ControlState(enabled: true));

          expect(pressed1, isFalse);
          expect(pressed2, isTrue);
          expect(pressed3, isFalse);
        }
      },
      variant: const TargetPlatformVariant(
        {TargetPlatform.macOS, TargetPlatform.iOS},
      ),
    );

    testWidgets('disabled button is ignored', (tester) async {
      const button1 = ValueKey('button1');
      late ControlState state1;
      bool pressed1;

      const button2 = ValueKey('button2');
      late ControlState state2;

      await tester.pumpWidget(
        Center(
          child: ButtonGroup(
            allowedDeviceKind: const {PointerDeviceKind.mouse, PointerDeviceKind.touch},
            child: Row(
              textDirection: TextDirection.ltr,
              mainAxisSize: MainAxisSize.min,
              children: [
                _TestButton(
                  key: button1,
                  onPressed: () {
                    pressed1 = true;
                  },
                  onStateChanged: (s) {
                    state1 = s;
                  },
                ),
                _TestButton(
                  key: button2,
                  onStateChanged: (s) {
                    state2 = s;
                  },
                ),
              ],
            ),
          ),
        ),
      );

      final gesture = await tester.createPlatformGesture(initialLocation: Offset.zero);
      for (int i = 0; i < 2; ++i) {
        pressed1 = false;

        await gesture.down(tester.getCenter(find.byKey(button1)));
        await tester.pump();

        expect(
          state1,
          ControlState(enabled: true, tracked: true, pressed: true),
        );
        expect(state2, ControlState());

        await gesture.moveTo(tester.getCenter(find.byKey(button2)));
        // Needed to invoke onUpdate callback.
        await gesture.moveBy(const Offset(1, 1));
        await tester.pump();

        expect(
          state1,
          ControlState(enabled: true, tracked: true, pressed: false),
        );
        expect(state2, ControlState());

        await gesture.up();
        await tester.pump();

        expect(state1, ControlState(enabled: true));
        expect(state2, ControlState());
        expect(pressed1, isFalse);
      }
    });

    testWidgets('can start on disabled button', (tester) async {
      const button1 = ValueKey('button1');
      late ControlState state1;
      bool pressed1;

      const button2 = ValueKey('button2');
      late ControlState state2;

      await tester.pumpWidget(
        Center(
          child: ButtonGroup(
            allowedDeviceKind: const {PointerDeviceKind.mouse, PointerDeviceKind.touch},
            child: Row(
              textDirection: TextDirection.ltr,
              mainAxisSize: MainAxisSize.min,
              children: [
                _TestButton(
                  key: button1,
                  onPressed: () {
                    pressed1 = true;
                  },
                  onStateChanged: (s) {
                    state1 = s;
                  },
                ),
                _TestButton(
                  key: button2,
                  onStateChanged: (s) {
                    state2 = s;
                  },
                ),
              ],
            ),
          ),
        ),
      );

      final gesture = await tester.createPlatformGesture(initialLocation: Offset.zero);
      for (int i = 0; i < 2; ++i) {
        pressed1 = false;

        await gesture.down(tester.getCenter(find.byKey(button2)));
        await tester.pump();

        expect(state1, ControlState(enabled: true));
        expect(state2, ControlState());

        await gesture.moveTo(tester.getCenter(find.byKey(button1)));
        // Needed to invoke onUpdate callback.
        await gesture.moveBy(const Offset(1, 1));
        await tester.pump();

        expect(
          state1,
          ControlState(enabled: true, tracked: true, pressed: true),
        );
        expect(state2, ControlState());

        await gesture.up();
        await tester.pump();

        expect(state1, ControlState(enabled: true, hovered: isMouse));
        expect(state2, ControlState());
        expect(pressed1, isTrue);
      }
    });
  });

  group('keyboard', () {
    testWidgets('space triggers onPressed', (tester) async {
      const button = ValueKey('button');
      bool pressed;
      late ControlState state;
      await tester.pumpWidget(
        Center(
          child: _TestButton(
            key: button,
            onPressed: () {
              pressed = true;
            },
            onStateChanged: (s) {
              state = s;
            },
          ),
        ),
      );

      expect(state, ControlState(enabled: true));

      final focus = tester.widget<Focus>(find.bySubtype<Focus>());
      focus.focusNode!.requestFocus();
      await tester.pumpAndSettle();
      expect(state, ControlState(enabled: true, focused: true));

      for (int i = 0; i < 2; ++i) {
        pressed = false;

        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        await tester.pump();

        expect(
          state,
          ControlState(enabled: true, focused: true, pressed: true),
        );
        expect(pressed, isFalse);

        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(state, ControlState(enabled: true, focused: true));

        expect(pressed, isTrue);
      }
    });

    testWidgets('space triggers onPressedDown', (tester) async {
      const button = ValueKey('button');
      late ControlState state;
      bool pressed;
      bool pressedDown;
      final completer = [Completer<void>()];

      await tester.pumpWidget(
        Center(
          child: _TestButton(
            key: button,
            onPressed: () {
              pressed = true;
            },
            onPressedDown: () {
              pressedDown = true;
              return completer[0].future;
            },
            onStateChanged: (s) {
              state = s;
            },
          ),
        ),
      );

      final focus = tester.widget<Focus>(find.bySubtype<Focus>());
      focus.focusNode!.requestFocus();
      await tester.pumpAndSettle();
      expect(state, ControlState(enabled: true, focused: true));

      for (int i = 0; i < 2; ++i) {
        pressed = false;
        pressedDown = false;
        completer[0] = Completer<void>();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        await tester.pump();

        expect(
          state,
          ControlState(enabled: true, focused: true, pressed: true),
        );
        expect(pressedDown, isTrue);

        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        await tester.pump();

        expect(pressed, isFalse);

        completer[0].complete();
        await tester.pumpAndSettle(); // required to flush microtasks.

        expect(pressed, isFalse);
        expect(state, ControlState(enabled: true, focused: true));
      }
    });

    testWidgets('key down after onPressedDown completes keeps button presed', (tester) async {
      const button = ValueKey('button');
      late ControlState state;
      bool pressedDown;
      final completer = [Completer<void>()];

      await tester.pumpWidget(
        Center(
          child: _TestButton(
            key: button,
            onPressedDown: () {
              pressedDown = true;
              return completer[0].future;
            },
            onStateChanged: (s) {
              state = s;
            },
          ),
        ),
      );

      final focus = tester.widget<Focus>(find.bySubtype<Focus>());
      focus.focusNode!.requestFocus();
      await tester.pumpAndSettle();
      expect(state, ControlState(enabled: true, focused: true));

      for (int i = 0; i < 2; ++i) {
        pressedDown = false;
        completer[0] = Completer<void>();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        await tester.pump();

        expect(
          state,
          ControlState(enabled: true, focused: true, pressed: true),
        );
        expect(pressedDown, isTrue);

        completer[0].complete();
        await tester.pumpAndSettle(); // required to flush microtasks.

        expect(
          state,
          ControlState(enabled: true, focused: true, pressed: true),
        );

        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        await tester.pump();

        expect(state, ControlState(enabled: true, focused: true));
      }
    });

    testWidgetsFakeAsync('pressDownDelay works with space', (tester, async) async {
      const button = ValueKey('button');
      late ControlState state;
      bool pressed;
      bool pressedDown;
      final completer = [Completer<void>()];

      await tester.pumpWidget(
        Center(
          child: _TestButton(
            key: button,
            onPressed: () {
              pressed = true;
            },
            pressDownDelay: const Duration(seconds: 1),
            onPressedDown: () {
              pressedDown = true;
              return completer[0].future;
            },
            onStateChanged: (s) {
              state = s;
            },
          ),
        ),
      );

      final focus = tester.widget<Focus>(find.bySubtype<Focus>());
      focus.focusNode!.requestFocus();
      await tester.pumpAndSettle();
      expect(state, ControlState(enabled: true, focused: true));

      for (int i = 0; i < 2; ++i) {
        pressed = false;
        pressedDown = false;

        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        await tester.pump();

        expect(
          state,
          ControlState(enabled: true, focused: true, pressed: true),
        );
        expect(pressedDown, isFalse);

        await Future.delayed(const Duration(milliseconds: 500));
        expect(
          state,
          ControlState(enabled: true, focused: true, pressed: true),
        );
        expect(pressedDown, isFalse);

        await Future.delayed(const Duration(milliseconds: 500));
        expect(
          state,
          ControlState(enabled: true, focused: true, pressed: true),
        );
        expect(pressedDown, isTrue);

        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        await tester.pump();

        completer[0].complete();
        await tester.pumpAndSettle(); // required to flush microtasks.

        expect(
          state,
          ControlState(enabled: true),
        );
        expect(pressed, isFalse);
      }
    });

    testWidgetsFakeAsync(
      'pressDownDelay not reached results in onPressed called',
      (tester, async) async {
        const button = ValueKey('button');
        late ControlState state;
        bool pressed;
        bool pressedDown;
        final completer = [Completer<void>()];

        await tester.pumpWidget(
          Center(
            child: _TestButton(
              key: button,
              onPressed: () {
                pressed = true;
              },
              pressDownDelay: const Duration(seconds: 1),
              onPressedDown: () {
                pressedDown = true;
                return completer[0].future;
              },
              onStateChanged: (s) {
                state = s;
              },
            ),
          ),
        );

        final focus = tester.widget<Focus>(find.bySubtype<Focus>());
        focus.focusNode!.requestFocus();
        await tester.pumpAndSettle();
        expect(state, ControlState(enabled: true, focused: true));

        for (int i = 0; i < 2; ++i) {
          pressed = false;
          pressedDown = false;

          await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
          await tester.pump();

          expect(
            state,
            ControlState(enabled: true, focused: true, pressed: true),
          );
          expect(pressedDown, isFalse);

          await Future.delayed(const Duration(milliseconds: 500));
          expect(
            state,
            ControlState(enabled: true, focused: true, pressed: true),
          );
          expect(pressedDown, isFalse);

          // Release before the long press delay.
          await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
          await tester.pump();

          expect(
            state,
            ControlState(enabled: true, focused: true),
          );

          expect(pressed, isTrue);
          expect(pressed, isFalse);

          // Check that the timeout was cancelled.
          await Future.delayed(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();
          expect(pressedDown, isFalse);
        }
      },
    );

    testWidgetsFakeAsync('keyUpTimeout works', (tester, async) async {
      const button = ValueKey('button');
      late ControlState state;
      bool pressed;

      await tester.pumpWidget(
        Center(
          child: _TestButton(
            key: button,
            onPressed: () {
              pressed = true;
            },
            keyUpTimeout: const Duration(milliseconds: 200),
            onStateChanged: (s) {
              state = s;
            },
          ),
        ),
      );

      final focus = tester.widget<Focus>(find.bySubtype<Focus>());
      focus.focusNode!.requestFocus();
      await tester.pumpAndSettle();
      expect(state, ControlState(enabled: true, focused: true));

      for (int i = 0; i < 2; ++i) {
        pressed = false;

        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        await tester.pump();

        expect(
          state,
          ControlState(enabled: true, focused: true, pressed: true),
        );
        expect(pressed, isFalse);

        // after the timeout button is considered pressed (and released);
        await Future.delayed(const Duration(milliseconds: 200));

        expect(
          state,
          ControlState(enabled: true, focused: true, pressed: true),
        );
        expect(pressed, isTrue);

        // Ensure releasing the key does not press the button again.
        pressed = false;
        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        await tester.pump();

        expect(pressed, isFalse);
      }
    });

    testWidgetsFakeAsync('keyUpTimeout is ignored with onPressedDown', (tester, async) async {
      const button = ValueKey('button');
      late ControlState state;
      bool pressed;
      bool pressedDown;
      final completer = [Completer<void>()];

      await tester.pumpWidget(
        Center(
          child: _TestButton(
            key: button,
            onPressed: () {
              pressed = true;
            },
            pressDownDelay: const Duration(seconds: 1),
            keyUpTimeout: const Duration(milliseconds: 400),
            onPressedDown: () {
              pressedDown = true;
              return completer[0].future;
            },
            onStateChanged: (s) {
              state = s;
            },
          ),
        ),
      );

      final focus = tester.widget<Focus>(find.bySubtype<Focus>());
      focus.focusNode!.requestFocus();
      await tester.pumpAndSettle();
      expect(state, ControlState(enabled: true, focused: true));

      for (int i = 0; i < 2; ++i) {
        pressed = false;
        pressedDown = false;

        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        await tester.pump();

        expect(
          state,
          ControlState(enabled: true, focused: true, pressed: true),
        );
        expect(pressedDown, isFalse);

        await Future.delayed(const Duration(milliseconds: 1000));
        expect(
          state,
          ControlState(enabled: true, focused: true, pressed: true),
        );
        expect(pressedDown, isTrue);

        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        await tester.pump();

        completer[0].complete();
        await tester.pumpAndSettle(); // required to flush microtasks.

        expect(
          state,
          ControlState(enabled: true),
        );
        expect(pressed, isFalse);
      }
    });
  });
  group('keyboard navigation', () {
    testWidgets('disabled button can\'t be focused', (tester) async {
      late ControlState state1;
      late ControlState state2;
      late ControlState state3;

      await tester.pumpWidget(
        TestApp(
          home: Row(
            children: [
              _TestButton(
                onPressed: () {},
                onStateChanged: (s) {
                  state1 = s;
                },
              ),
              _TestButton(
                onStateChanged: (s) {
                  state2 = s;
                },
              ),
              _TestButton(
                onPressed: () {},
                onStateChanged: (s) {
                  state3 = s;
                },
              ),
            ],
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(state1, ControlState(focused: true, enabled: true));
      expect(state2, ControlState());
      expect(state3, ControlState(enabled: true));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(state1, ControlState(enabled: true));
      expect(state2, ControlState());
      expect(state3, ControlState(enabled: true, focused: true));
    });

    testWidgets('disabling/enabling button updates focusability', (tester) async {
      late ControlState state1;
      late ControlState state2;
      late ControlState state3;

      await tester.pumpWidget(
        TestApp(
          home: Row(
            children: [
              _TestButton(
                onPressed: () {},
                onStateChanged: (s) {
                  state1 = s;
                },
              ),
              _TestButton(
                onPressed: () {},
                onStateChanged: (s) {
                  state2 = s;
                },
              ),
              _TestButton(
                onStateChanged: (s) {
                  state3 = s;
                },
              ),
            ],
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(state1, ControlState(focused: true, enabled: true));
      expect(state2, ControlState(enabled: true));
      expect(state3, ControlState());

      await tester.pumpWidget(
        TestApp(
          home: Row(
            textDirection: TextDirection.ltr,
            mainAxisSize: MainAxisSize.min,
            children: [
              _TestButton(
                onPressed: () {},
                onStateChanged: (s) {
                  state1 = s;
                },
              ),
              _TestButton(
                onStateChanged: (s) {
                  state2 = s;
                },
              ),
              _TestButton(
                onPressed: () {},
                onStateChanged: (s) {
                  state3 = s;
                },
              ),
            ],
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(state1, ControlState(enabled: true));
      expect(state2, ControlState());
      expect(state3, ControlState(enabled: true, focused: true));
    });

    testWidgets('unfocusing pressed button does not submit', (tester) async {
      late ControlState state1;
      late ControlState state2;
      bool pressed = false;

      await tester.pumpWidget(
        TestApp(
          home: Row(
            children: [
              _TestButton(
                onPressed: () {
                  pressed = true;
                },
                onStateChanged: (s) {
                  state1 = s;
                },
              ),
              _TestButton(
                onPressed: () {},
                onStateChanged: (s) {
                  state2 = s;
                },
              ),
            ],
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(state1, ControlState(focused: true, enabled: true));
      expect(state2, ControlState(enabled: true));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(state1, ControlState(focused: true, enabled: true, pressed: true));
      expect(state2, ControlState(enabled: true));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(state1, ControlState(enabled: true));
      expect(state2, ControlState(enabled: true, focused: true));

      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(pressed, isFalse);
    });

    testWidgetsFakeAsync('unfocusing armed button does not submit', (tester, async) async {
      late ControlState state1;
      late ControlState state2;
      bool pressed = false;
      await tester.pumpWidget(
        TestApp(
          home: Row(
            children: [
              _TestButton(
                keyUpTimeout: const Duration(milliseconds: 400),
                onPressed: () {
                  pressed = true;
                },
                onStateChanged: (s) {
                  state1 = s;
                },
              ),
              _TestButton(
                onPressed: () {},
                onStateChanged: (s) {
                  state2 = s;
                },
              ),
            ],
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(state1, ControlState(focused: true, enabled: true));
      expect(state2, ControlState(enabled: true));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(state1, ControlState(focused: true, enabled: true, pressed: true));
      expect(state2, ControlState(enabled: true));

      async.elapse(const Duration(milliseconds: 300));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(state1, ControlState(enabled: true));
      expect(state2, ControlState(enabled: true, focused: true));

      async.elapse(const Duration(milliseconds: 300));

      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(pressed, isFalse);
    });
  });
}
