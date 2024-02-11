// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Colors, Typography;
import 'package:headless_widgets/headless_widgets.dart';
import 'package:pixel_snap/widgets.dart';

import 'popover_delegate.dart';
import 'widgets.dart';

void main() {
  Widget app = const MainApp();
  if (!kIsWeb && kDebugMode) {
    app = PixelSnapDebugBar(child: app);
  }
  runApp(app);
}

class MinimalApp extends StatelessWidget {
  const MinimalApp({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      color: Colors.blue,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
        return PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (context, _, __) => builder(context));
      },
      home: DefaultTextStyle(
        style: Typography.material2018(platform: defaultTargetPlatform)
            .englishLike
            .bodyMedium!,
        child: ColoredBox(
          color: Colors.grey.shade100,
          child: child,
        ),
      ),
    );
  }
}

// Normal button
// Click to focus
// Armed
// Popover
// Button Group

class _Section extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const _Section({
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
        color: Colors.grey.shade200,
      ),
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(color: Colors.grey.shade800),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ButtonRow extends StatelessWidget {
  const _ButtonRow({
    // ignore: unused_element
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: children
          .intersperse(
            const SizedBox(width: 10),
          )
          .toList(growable: false),
    );
  }
}

class _Popover extends StatefulWidget {
  const _Popover({
    // ignore: unused_element
    super.key,
    required this.controller,
  });

  final PopoverController controller;

  @override
  State<_Popover> createState() => _PopoverState();
}

class _PopoverState extends State<_Popover> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
      ),
      child: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          padding:
              expanded ? const EdgeInsets.all(50) : const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Popover contents',
                style: TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SampleButton(
                    onPressed: () {
                      widget.controller.hidePopover();
                    },
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 10),
                  SampleButton(
                    onPressed: () {
                      setState(() {
                        expanded = !expanded;
                      });
                    },
                    child: expanded
                        ? const Text('Collapse')
                        : const Text('Expand'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class PopoverButton extends StatefulWidget {
  const PopoverButton({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<PopoverButton> createState() => _PopoverButtonState();
}

class _PopoverButtonState extends State<PopoverButton> {
  final _controller = PopoverController();

  @override
  Widget build(BuildContext context) {
    return PopoverAnchor(
      controller: _controller,
      delegate: () => SamplePopoverDelegate(attachments: [
        const PopoverAttachment(
            anchor: Alignment.centerLeft, popover: Alignment.centerRight),
        const PopoverAttachment(
            anchor: Alignment.bottomCenter, popover: Alignment.topCenter),
        const PopoverAttachment(
            anchor: Alignment.topCenter, popover: Alignment.bottomCenter),
      ]),
      animationDuration: const Duration(milliseconds: 200),
      animationReverseDuration: const Duration(milliseconds: 150),
      child: SampleButton(
        onPressed: () async {
          await _controller.showPopover(_Popover(
            controller: _controller,
          ));
        },
        child: widget.child,
      ),
    );
  }
}

final controller = PixelSnapScrollController();

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MinimalApp(
      child: SingleChildScrollView(
        controller: controller,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Section(
                  title: 'Regular Button',
                  description:
                      'Requires tab to focus. Default behavior on most platforms.',
                  child: _ButtonRow(
                    children: [
                      SampleButton(
                        onPressed: () {
                          print('Pressed 1');
                        },
                        child: const Text('Button 1'),
                      ),
                      SampleButton(
                        onPressed: () {
                          print('Pressed 2');
                        },
                        child: const Text('Button 2'),
                      ),
                      const SampleButton(
                        child: Text('Disabled'),
                      ),
                    ],
                  )),
              _Section(
                  title: 'Tap to Focus',
                  description: 'Button focuses itself on pointer interaction.',
                  child: _ButtonRow(
                    children: [
                      SampleButton(
                        tapToFocus: true,
                        onPressed: () {
                          print('Pressed 1');
                        },
                        child: const Text('Button 1'),
                      ),
                      SampleButton(
                        tapToFocus: true,
                        onPressed: () {
                          print('Pressed 2');
                        },
                        child: const Text('Button 2'),
                      ),
                      const SampleButton(
                        tapToFocus: true,
                        child: Text('Disabled'),
                      ),
                    ],
                  )),
              const _Section(
                title: 'Popover',
                description: 'Button shows popover when pressed',
                child: _ButtonRow(
                  children: [
                    PopoverButton(
                      child: Text('Show Popover 1\nMulti line'),
                    ),
                    Spacer(),
                    PopoverButton(
                      child: Text('Show Popover 2'),
                    ),
                    Spacer(),
                  ],
                ),
              ),
              _Section(
                  title: 'KeyUp timeout',
                  description:
                      'onPressed callback is called after keyUpTimeout if key is held down. Default behavior on macOS and Linux.',
                  child: _ButtonRow(
                    children: [
                      SampleButton(
                        keyUpTimeout: const Duration(milliseconds: 250),
                        onPressed: () {
                          print('Pressed 1');
                        },
                        child: const Text('Button 1'),
                      ),
                      SampleButton(
                        keyUpTimeout: const Duration(milliseconds: 250),
                        onPressed: () {
                          print('Pressed 2');
                        },
                        child: const Text('Button 2'),
                      ),
                      const SampleButton(
                        keyUpTimeout: Duration(milliseconds: 250),
                        child: Text('Disabled'),
                      ),
                    ],
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

extension IntersperseExtensions<T> on Iterable<T> {
  Iterable<T> intersperse(T element) sync* {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      yield iterator.current;
      while (iterator.moveNext()) {
        yield element;
        yield iterator.current;
      }
    }
  }
}
