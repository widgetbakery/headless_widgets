import 'package:flutter/widgets.dart';

Offset fitRectInBounds({required Rect bounds, required Rect rect}) {
  final dx1 = rect.left < bounds.left ? bounds.left - rect.left : 0.0;
  final dx2 = rect.right > bounds.right ? bounds.right - rect.right : 0.0;
  final dy1 = rect.top < bounds.top ? bounds.top - rect.top : 0.0;
  final dy2 = rect.bottom > bounds.bottom ? bounds.bottom - rect.bottom : 0.0;
  return Offset(dx1 + dx2, dy1 + dy2);
}
