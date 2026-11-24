import 'package:flutter_test/flutter_test.dart';
import 'package:fore_last_stand/data/clubs.dart';
import 'package:fore_last_stand/data/enemies.dart';

void main() {
  test('clubs have unique ids and the four spec clubs', () {
    expect(clubs.map((c) => c.id).toSet().length, clubs.length);
    expect(clubs.map((c) => c.id), containsAll(['driver', 'iron', 'wedge', 'putter']));
  });

  test('enemies have unique ids and positive stats', () {
    expect(enemies.map((e) => e.id).toSet().length, enemies.length);
    for (final e in enemies) {
      expect(e.health, greaterThan(0));
      expect(e.speed, greaterThan(0));
    }
  });
}
