import 'dart:ui';

const kEpsilon = 0.0001;

bool rectsEqual(Rect r1, Rect r2) {
  bool equals(double a, double b) => (a - b).abs() < kEpsilon;
  return equals(r1.left, r2.left) &&
      equals(r1.top, r2.top) &&
      equals(r1.right, r2.right) &&
      equals(r1.bottom, r2.bottom);
}
