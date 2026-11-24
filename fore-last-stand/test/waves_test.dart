import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fore_last_stand/data/courses.dart';
import 'package:fore_last_stand/data/enemies.dart';
import 'package:fore_last_stand/sim/waves.dart';

void main() {
  test('Suburban Muni has 9 holes, breathers on 3 and 6, boss on 9', () {
    final holes = suburbanMuni.holes;
    expect(holes, hasLength(9));
    expect(holes[2].breather, isTrue);
    expect(holes[5].breather, isTrue);
    expect(holes[8].hasBoss, isTrue);
    expect(holes.take(8).any((h) => h.hasBoss), isFalse);
  });

  test('hole 1 introduces one enemy type and hole 5 mixes four', () {
    Set<String> types(HoleSpec h) => h.groups.map((g) => g.enemyId).toSet();
    expect(types(suburbanMuni.holes[0]), hasLength(1));
    expect(types(suburbanMuni.holes[4]), hasLength(4));
  });

  test('every spawn group references a real enemy', () {
    for (final h in [...suburbanMuni.holes, miniBossHole]) {
      for (final g in h.groups) {
        expect(() => enemyById(g.enemyId), returnsNormally, reason: g.enemyId);
      }
    }
  });

  test('schedules are sorted and scale with count but never scale bosses', () {
    final s = scheduleHole(suburbanMuni.holes[8], math.Random(1), countScale: 2);
    for (var i = 1; i < s.length; i++) {
      expect(s[i].time, greaterThanOrEqualTo(s[i - 1].time));
    }
    expect(s.where((x) => x.enemyId == 'goose_king'), hasLength(1));
    final base = scheduleHole(suburbanMuni.holes[8], math.Random(1));
    expect(s.length, greaterThan(base.length));
  });

  test('endless holes grow, have breathers every third and a boss every ninth', () {
    final h1 = generateHole(0, math.Random(1));
    final h8 = generateHole(7, math.Random(1));
    expect(h8.enemyCount, greaterThan(h1.enemyCount));
    expect(generateHole(2, math.Random(1)).breather, isTrue);
    expect(generateHole(8, math.Random(1)).hasBoss, isTrue);
    expect(generateHole(17, math.Random(1)).hasBoss, isTrue);
    expect(generateHole(4, math.Random(1)).hasBoss, isFalse);
  });
}
