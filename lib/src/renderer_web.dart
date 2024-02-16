import 'dart:js_interop' as js;
import 'dart:js_interop_unsafe';

import 'renderer.dart';

final isCanvasKit = js.globalContext['flutterCanvasKit'] != null;

FlutterRenderer getCurrentRendererImpl() {
  return isCanvasKit ? FlutterRenderer.canvasKit : FlutterRenderer.html;
}
