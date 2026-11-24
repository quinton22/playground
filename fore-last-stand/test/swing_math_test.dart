import 'package:flutter_test/flutter_test.dart';
import 'package:fore_last_stand/game/swing_math.dart';

void main() {
  test('ball flies opposite to the drag', () {
    final s = swingFromDrag(0, 80)!; // dragged down -> ball goes up
    expect(s.direction.dx, closeTo(0, 1e-9));
    expect(s.direction.dy, closeTo(-1, 1e-9));
    expect(s.power, closeTo(0.5, 1e-9));
  });

  test('power is clamped to 1', () {
    expect(swingFromDrag(0, 1000)!.power, 1.0);
  });

  test('tiny drags are not swings', () {
    expect(swingFromDrag(2, 2), isNull);
  });

  test('sweet spot window', () {
    expect(isSweetSpot(0.5), isTrue);
    expect(isSweetSpot(0.9), isFalse);
  });
}
