import 'dart:math' as math;

import '../data/courses.dart';

class ScheduledSpawn {
  const ScheduledSpawn(this.time, this.enemyId, this.edge);

  final double time;
  final String enemyId;
  final SpawnEdge edge;
}

/// Turns a hole's spawn groups into a time-sorted queue.
/// [countScale] grows swarms (fallen flags) or shrinks them (adaptive difficulty).
/// Bosses are never scaled.
List<ScheduledSpawn> scheduleHole(HoleSpec hole, math.Random rng, {double countScale = 1}) {
  final out = <ScheduledSpawn>[];
  for (final g in hole.groups) {
    final boss = g.enemyId == 'goose_king';
    final n = boss ? g.count : math.max(1, (g.count * countScale).round());
    final interval = boss ? g.interval : g.interval * g.count / n;
    for (var i = 0; i < n; i++) {
      final jitter = boss ? 0.0 : rng.nextDouble() * 0.3;
      out.add(ScheduledSpawn(g.delay + i * interval + jitter, g.enemyId, g.edge));
    }
  }
  out.sort((a, b) => a.time.compareTo(b.time));
  return out;
}

/// Enemies in the order they join endless runs.
const List<String> endlessRoster = ['goose', 'raccoon', 'crow', 'gator', 'squirrel', 'boar', 'skunk', 'coyote'];

/// Rough threat cost per enemy for the endless budget.
const Map<String, int> threatCost = {
  'goose': 2,
  'raccoon': 3,
  'crow': 2,
  'gator': 6,
  'squirrel': 3,
  'boar': 5,
  'skunk': 4,
  'coyote': 9,
};

/// Endless/daily hole [index] (0-based): a budget of threat spread over the
/// unlocked roster, a breather every third hole and a boss every ninth.
HoleSpec generateHole(int index, math.Random rng) {
  final number = index + 1;
  final boss = number % 9 == 0;
  final breather = !boss && number % 3 == 0;
  var budget = 16 + 7 * index;
  if (breather) budget = (budget * 0.65).round();
  final unlocked = endlessRoster.take(math.min(endlessRoster.length, 1 + index)).toList();
  final counts = <String, int>{};
  while (budget > 0) {
    final id = unlocked[rng.nextInt(unlocked.length)];
    final cost = threatCost[id]!;
    if (cost > budget) {
      counts['goose'] = (counts['goose'] ?? 0) + 1;
      budget -= threatCost['goose']!;
      continue;
    }
    counts[id] = (counts[id] ?? 0) + 1;
    budget -= cost;
  }
  final groups = <SpawnGroup>[
    if (boss) const SpawnGroup('goose_king', 1, delay: 2),
    for (final e in counts.entries)
      SpawnGroup(
        e.key,
        e.value,
        interval: math.max(0.6, 2.2 - index * 0.08),
        delay: rng.nextDouble() * 6,
        edge: e.key == 'gator'
            ? SpawnEdge.water
            : (e.key == 'raccoon' || e.key == 'squirrel' || e.key == 'skunk')
                ? SpawnEdge.sides
                : SpawnEdge.any,
      ),
  ];
  final total = counts.values.fold(0, (a, b) => a + b);
  return HoleSpec(
    groups: groups,
    par: 20 + total * 1.6 + (boss ? 40 : 0),
    breather: breather,
    coinBonus: breather ? 20 + 5 * index : 0,
    bossScale: boss ? 1 + 0.25 * (number ~/ 9 - 1) : 1,
  );
}
