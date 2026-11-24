import 'dart:math' as math;

/// Tiny immutable 2D vector used by the simulation (keeps `lib/sim` free of Flame).
class V2 {
  const V2(this.x, this.y);

  static const zero = V2(0, 0);

  final double x;
  final double y;

  V2 operator +(V2 o) => V2(x + o.x, y + o.y);
  V2 operator -(V2 o) => V2(x - o.x, y - o.y);
  V2 operator *(double s) => V2(x * s, y * s);
  V2 operator /(double s) => V2(x / s, y / s);
  V2 operator -() => V2(-x, -y);

  double get length => math.sqrt(x * x + y * y);
  double get length2 => x * x + y * y;
  double dot(V2 o) => x * o.x + y * o.y;
  double distanceTo(V2 o) => (this - o).length;

  V2 normalized() {
    final l = length;
    return l == 0 ? V2.zero : V2(x / l, y / l);
  }

  V2 rotated(double radians) {
    final c = math.cos(radians), s = math.sin(radians);
    return V2(x * c - y * s, x * s + y * c);
  }

  /// Reflects this vector about a surface with unit normal [n].
  V2 reflect(V2 n) => this - n * (2 * dot(n));

  double get angle => math.atan2(y, x);

  @override
  bool operator ==(Object other) => other is V2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'V2(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}

/// Axis-aligned rectangle.
class Box {
  const Box(this.left, this.top, this.right, this.bottom);

  final double left, top, right, bottom;

  double get width => right - left;
  double get height => bottom - top;
  V2 get center => V2((left + right) / 2, (top + bottom) / 2);

  bool contains(V2 p) => p.x >= left && p.x <= right && p.y >= top && p.y <= bottom;

  /// Closest point inside the box to [p].
  V2 clamp(V2 p) => V2(p.x.clamp(left, right).toDouble(), p.y.clamp(top, bottom).toDouble());

  bool intersectsCircle(V2 c, double r) => clamp(c).distanceTo(c) <= r;
}
