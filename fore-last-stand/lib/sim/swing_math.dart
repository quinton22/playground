import 'dart:math' as math;

import 'vec.dart';

/// Result of a drag-back gesture.
class Swing {
  const Swing({required this.direction, required this.power});

  /// Unit vector the ball travels along.
  final V2 direction;

  /// 0..1
  final double power;
}

/// Max drag distance (world units) that maps to full power.
const double maxDragDistance = 160;

/// Drag *back*: the ball flies opposite to the drag.
/// Returns null for drags too short to count as a swing.
Swing? swingFromDrag(double dragDx, double dragDy, {double minDistance = 12}) {
  final len = math.sqrt(dragDx * dragDx + dragDy * dragDy);
  if (len < minDistance) return null;
  return Swing(
    direction: V2(-dragDx / len, -dragDy / len),
    power: math.min(len / maxDragDistance, 1.0),
  );
}

/// Seconds for the timing ring to pulse once.
const double timingRingPeriod = 1.1;

/// Phase 0..1 of the timing ring after [seconds] of drag.
double ringPhase(double seconds) => (seconds % timingRingPeriod) / timingRingPeriod;

/// Sweet Spot: release while the timing ring (phase 0..1) is in the green zone.
bool isSweetSpot(double ringPhase, {double center = 0.5, double width = 0.16}) =>
    (ringPhase - center).abs() <= width / 2;

const double sweetSpotDamageMultiplier = 1.5;

/// Base seconds between swings (spec 3: about 0.8 s).
const double baseSwingCooldown = 0.8;

/// Rotates [dir] toward [toTarget] when it lies within [maxAngle] radians,
/// by [strength] (0..1) of the gap. Used by the aim-assist slider.
V2 assistAim(V2 dir, V2 toTarget, double strength, {double maxAngle = 0.35}) {
  if (strength <= 0 || toTarget.length == 0) return dir;
  var delta = toTarget.angle - dir.angle;
  while (delta > math.pi) {
    delta -= 2 * math.pi;
  }
  while (delta < -math.pi) {
    delta += 2 * math.pi;
  }
  if (delta.abs() > maxAngle) return dir;
  return dir.rotated(delta * strength.clamp(0, 1));
}

/// Straight-line preview from [origin] along [dir] for [length], reflecting off the
/// side walls and the top of a [width]-wide board once (the "first bounce" arc).
List<V2> previewPath(V2 origin, V2 dir, double length, double width, {int maxBounces = 1}) {
  final points = [origin];
  var p = origin, d = dir, left = length;
  for (var b = 0; b <= maxBounces && left > 0; b++) {
    // Distance to each wall along d.
    var t = double.infinity;
    V2? normal;
    if (d.x < 0) {
      final tx = (0 - p.x) / d.x;
      if (tx < t) (t, normal) = (tx, const V2(1, 0));
    } else if (d.x > 0) {
      final tx = (width - p.x) / d.x;
      if (tx < t) (t, normal) = (tx, const V2(-1, 0));
    }
    if (d.y < 0) {
      final ty = (0 - p.y) / d.y;
      if (ty < t) (t, normal) = (ty, const V2(0, 1));
    }
    if (t >= left || normal == null) {
      points.add(p + d * left);
      break;
    }
    p = p + d * t;
    points.add(p);
    left -= t;
    d = d.reflect(normal);
  }
  return points;
}
