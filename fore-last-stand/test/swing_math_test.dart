import 'package:flutter_test/flutter_test.dart';
import 'package:fore_last_stand/sim/swing_math.dart';
import 'package:fore_last_stand/sim/vec.dart';

void main() {
  test('ball flies opposite to the drag', () {
    final s = swingFromDrag(0, 80)!; // dragged down -> ball goes up
    expect(s.direction.x, closeTo(0, 1e-9));
    expect(s.direction.y, closeTo(-1, 1e-9));
    expect(s.power, closeTo(0.5, 1e-9));
  });

  test('power is clamped to 1', () {
    expect(swingFromDrag(0, 1000)!.power, 1.0);
  });

  test('tiny drags are not swings', () {
    expect(swingFromDrag(2, 2), isNull);
  });

  test('sweet spot window and ring phase', () {
    expect(isSweetSpot(0.5), isTrue);
    expect(isSweetSpot(0.9), isFalse);
    expect(ringPhase(timingRingPeriod * 1.5), closeTo(0.5, 1e-9));
  });

  test('aim assist nudges toward a nearby target only', () {
    const up = V2(0, -1);
    final nudged = assistAim(up, const V2(0.2, -1), 1);
    expect(nudged.x, greaterThan(0));
    expect(assistAim(up, const V2(1, 0), 1), up, reason: 'too far off');
    expect(assistAim(up, const V2(0.2, -1), 0), up);
  });

  test('preview path reflects off a side wall once', () {
    final path = previewPath(const V2(180, 600), const V2(-0.6, -0.8), 1000, 360);
    expect(path, hasLength(3));
    expect(path[1].x, closeTo(0, 1e-6));
    expect(path[2].x, greaterThan(0));
  });
}
