import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

mixin FocusableControlMixin<T extends StatefulWidget> on State<T> {
  late FocusNode focusNode;

  @override
  void initState() {
    super.initState();

    focusNode = getWidgetFocusNode(widget) ?? FocusNode(debugLabel: 'this');
    focusNode.onKeyEvent = onKeyEvent;
    focusNode.canRequestFocus = widgetIsEnabled;
  }

  @override
  void dispose() {
    super.dispose();
    if (getWidgetFocusNode(widget) != focusNode) {
      focusNode.dispose();
    }
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    final widgetFocusNode = getWidgetFocusNode(widget);
    if (widgetFocusNode != null && widgetFocusNode != focusNode) {
      focusNode.onKeyEvent = null;
      if (getWidgetFocusNode(oldWidget) == null) {
        // this was internal focus node
        focusNode.dispose();
      }
      focusNode = widgetFocusNode;
      focusNode.onKeyEvent = onKeyEvent;
    }
    focusNode.canRequestFocus = widgetIsEnabled;
  }

  FocusNode? getWidgetFocusNode(T widget);
  bool get widgetIsEnabled;
  KeyEventResult onKeyEvent(FocusNode node, KeyEvent event);
}
