import 'package:flutter_test/flutter_test.dart';
import 'package:fore_last_stand/data/caddies.dart';
import 'package:fore_last_stand/data/clubs.dart';
import 'package:fore_last_stand/data/commentary.dart';
import 'package:fore_last_stand/data/enemies.dart';
import 'package:fore_last_stand/data/perks.dart';
import 'package:fore_last_stand/data/towers.dart';

void main() {
  test('clubs have unique ids and the four spec clubs, three in the starter bag', () {
    expect(clubs.map((c) => c.id).toSet().length, clubs.length);
    expect(clubs.map((c) => c.id), containsAll(['driver', 'iron', 'wedge', 'putter']));
    expect(starterBag, hasLength(3));
  });

  test('MVP content counts: 8 enemies, 1 boss, 6 towers, 20 perks, 2 caddies', () {
    expect(bestiaryEntries.where((e) => !e.boss), hasLength(8));
    expect(bosses, hasLength(1));
    expect(towers, hasLength(6));
    expect(perks, hasLength(20));
    expect(caddies, hasLength(2));
  });

  test('enemies have unique ids and positive stats', () {
    final all = [...enemies, ...bosses];
    expect(all.map((e) => e.id).toSet().length, all.length);
    for (final e in all) {
      expect(e.health, greaterThan(0));
      expect(e.speed, greaterThan(0));
    }
  });

  test('perk and tower ids are unique', () {
    expect(perks.map((p) => p.id).toSet().length, perks.length);
    expect(towers.map((t) => t.id).toSet().length, towers.length);
    expect(towers.map((t) => t.badge).toSet().length, towers.length);
  });

  test('every commentary event has lines', () {
    for (final e in CommentEvent.values) {
      expect(commentary[e], isNotEmpty, reason: e.name);
    }
  });
}
