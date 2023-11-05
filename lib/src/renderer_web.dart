// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

import 'renderer.dart';

final isCanvasKit = js.context['flutterCanvasKit'] != null;

FlutterRenderer getCurrentRendererImpl() {
  return isCanvasKit ? FlutterRenderer.canvasKit : FlutterRenderer.html;
}
