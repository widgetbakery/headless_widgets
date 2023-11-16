<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->

A set of widgets that implement robust logic for common controls, without making
any assumption about the presentation.

This package focuses on correctness and flexibility, it is meant to back
custom design systems and custom widget sets.

## Features

Currently implemented widgets:

- [Button](lib/src/button.dart)
- [Popover](lib/src/popover.dart)

This package also includes [HoverRegion](lib/src/hover_region.dart) widget which is a drop-in replacement for `MouseRegion` that supports mouse-capture like behavior and delaying hover events during scrolling.

## Example

Available in the [example](example) directory and [online](https://widgetbakery.github.io/headless_widgets/).
