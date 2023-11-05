import 'renderer_native.dart' if (dart.library.js) 'renderer_web.dart';

enum FlutterRenderer {
  native,
  html,
  canvasKit,
}

/// Returns the renderer that is currently being used.
FlutterRenderer getCurrentRenderer() {
  return getCurrentRendererImpl();
}
