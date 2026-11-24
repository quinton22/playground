import '../sim/vec.dart';

/// Where a spawn group enters the board.
enum SpawnEdge { top, left, right, sides, any, water }

class SpawnGroup {
  const SpawnGroup(this.enemyId, this.count, {this.interval = 1.2, this.delay = 0, this.edge = SpawnEdge.top});

  final String enemyId;
  final int count;

  /// Seconds between spawns inside this group.
  final double interval;

  /// Seconds after the hole starts before the first spawn.
  final double delay;
  final SpawnEdge edge;
}

class HoleSpec {
  const HoleSpec({
    required this.groups,
    required this.par,
    this.breather = false,
    this.coinBonus = 0,
    this.bossScale = 1,
  });

  final List<SpawnGroup> groups;

  /// Target seconds to clear the hole (spec 2).
  final double par;

  /// Calmer hole with a coin bonus (spec 5: every third hole).
  final bool breather;
  final int coinBonus;

  /// Health multiplier for any boss in this hole (mini-boss < 1).
  final double bossScale;

  int get enemyCount => groups.fold(0, (n, g) => n + g.count);
  bool get hasBoss => groups.any((g) => g.enemyId == 'goose_king');
}

class CourseSpec {
  const CourseSpec({required this.id, required this.name, required this.holes, required this.water, required this.description});

  final String id;
  final String name;
  final String description;
  final List<HoleSpec> holes;

  /// Water hazards: gators surface from these.
  final List<Box> water;
}

const suburbanMuni = CourseSpec(
  id: 'suburban_muni',
  name: 'Suburban Muni',
  description: 'Water hazards everywhere. Gators surface from the ponds.',
  water: [Box(14, 130, 104, 180), Box(250, 210, 346, 258)],
  holes: [
    // 1: one enemy type.
    HoleSpec(par: 25, groups: [SpawnGroup('goose', 6, interval: 1.8, delay: 1)]),
    HoleSpec(par: 35, groups: [
      SpawnGroup('goose', 7, interval: 1.6),
      SpawnGroup('raccoon', 3, interval: 3, delay: 4, edge: SpawnEdge.sides),
    ]),
    // 3: breather.
    HoleSpec(par: 30, breather: true, coinBonus: 25, groups: [
      SpawnGroup('goose', 6, interval: 1.8),
      SpawnGroup('raccoon', 2, interval: 4, delay: 5, edge: SpawnEdge.sides),
    ]),
    HoleSpec(par: 45, groups: [
      SpawnGroup('goose', 8, interval: 1.4),
      SpawnGroup('crow', 4, interval: 2.5, delay: 4),
      SpawnGroup('raccoon', 3, interval: 3, delay: 8, edge: SpawnEdge.sides),
    ]),
    // 5: mixes four types.
    HoleSpec(par: 55, groups: [
      SpawnGroup('goose', 8, interval: 1.3),
      SpawnGroup('gator', 2, interval: 6, delay: 5, edge: SpawnEdge.water),
      SpawnGroup('crow', 4, interval: 2.2, delay: 7),
      SpawnGroup('squirrel', 3, interval: 3, delay: 10, edge: SpawnEdge.sides),
    ]),
    // 6: breather.
    HoleSpec(par: 40, breather: true, coinBonus: 40, groups: [
      SpawnGroup('goose', 8, interval: 1.4),
      SpawnGroup('crow', 3, interval: 3, delay: 5),
    ]),
    HoleSpec(par: 60, groups: [
      SpawnGroup('goose', 10, interval: 1.2),
      SpawnGroup('boar', 3, interval: 5, delay: 4),
      SpawnGroup('skunk', 2, interval: 8, delay: 8, edge: SpawnEdge.sides),
      SpawnGroup('squirrel', 4, interval: 2.5, delay: 12, edge: SpawnEdge.sides),
    ]),
    HoleSpec(par: 70, groups: [
      SpawnGroup('coyote', 2, interval: 12, delay: 2),
      SpawnGroup('gator', 3, interval: 5, delay: 6, edge: SpawnEdge.water),
      SpawnGroup('crow', 6, interval: 2, delay: 4),
      SpawnGroup('boar', 2, interval: 6, delay: 10),
      SpawnGroup('skunk', 2, interval: 7, delay: 14, edge: SpawnEdge.sides),
    ]),
    // 9: boss.
    HoleSpec(par: 90, groups: [
      SpawnGroup('goose_king', 1, delay: 2),
      SpawnGroup('goose', 10, interval: 2, delay: 6),
      SpawnGroup('crow', 4, interval: 4, delay: 12),
      SpawnGroup('raccoon', 3, interval: 6, delay: 15, edge: SpawnEdge.sides),
    ]),
  ],
);

/// Quick Round's hole 5: a mini-boss that is hard to lose to (spec 6, 10).
const miniBossHole = HoleSpec(par: 60, bossScale: 0.35, groups: [
  SpawnGroup('goose_king', 1, delay: 2),
  SpawnGroup('goose', 6, interval: 2.5, delay: 6),
  SpawnGroup('raccoon', 2, interval: 6, delay: 10, edge: SpawnEdge.sides),
]);

const List<CourseSpec> courses = [suburbanMuni];
