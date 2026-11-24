import 'dart:math' as math;

/// Result of a drag-back-from-the-tee gesture.
class Swing {
  const Swing({required this.direction, required this.power});

  /// Unit vector the ball travels along.
  final ({double dx, double dy}) direction;

  /// 0..1
  final double power;
}

/// Max drag distance (px) that maps to full power.
const double maxDragDistance = 160;

/// Drag *back* from the tee: the ball flies opposite to the drag.
/// Returns null for drags too short to count as a swing.
Swing? swingFromDrag(double dragDx, double dragDy, {double minDistance = 12}) {
  final len = math.sqrt(dragDx * dragDx + dragDy * dragDy);
  if (len < minDistance) return null;
  return Swing(
    direction: (dx: -dragDx / len, dy: -dragDy / len),
    power: math.min(len / maxDragDistance, 1.0),
  );
}

/// Sweet Spot: release while the timing ring (phase 0..1) is in the green zone.
bool isSweetSpot(double ringPhase, {double center = 0.5, double width = 0.12}) =>
    (ringPhase - center).abs() <= width / 2;

const double sweetSpotDamageMultiplier = 1.5;
