import 'dart:math' as math;

import '../data/caddies.dart';
import '../data/clubs.dart';
import '../data/modes.dart';
import '../sim/battle.dart';
import 'profile.dart';

/// Clubs level 1-20 (spec 7a). Traits arrive at 5, 10, 15 and 20.
const int maxClubLevel = 20;

int clubUpgradeCost(int level) => 10 + 6 * level;

String clubTrait(int level) => switch (level) {
      >= 20 => 'Trait IV: legend grip',
      >= 15 => 'Trait III: tour spin',
      >= 10 => 'Trait II: pro shaft',
      >= 5 => 'Trait I: soft feel',
      _ => 'No trait yet (level 5)',
    };

/// Clubhouse upgrade tree (spec 7: grows the grid, adds starting coins, hit points).
class ClubhouseUpgrade {
  const ClubhouseUpgrade(this.id, this.name, this.description, this.maxLevel, this.baseCost);

  final String id;
  final String name;
  final String description;
  final int maxLevel;
  final int baseCost;

  int cost(int level) => baseCost * (level + 1);
}

const List<ClubhouseUpgrade> clubhouseUpgrades = [
  ClubhouseUpgrade('grid', 'Grounds Expansion', 'Grow the plot grid: 4x4 -> 5x5 -> 6x6.', 2, 250),
  ClubhouseUpgrade('coins', 'Pro Shop Float', '+20 starting coins per level.', 5, 60),
  ClubhouseUpgrade('walls', 'Reinforced Walls', '+20 clubhouse HP per level.', 5, 80),
];

ClubhouseUpgrade clubhouseUpgradeById(String id) => clubhouseUpgrades.firstWhere((u) => u.id == id);

/// Builds a run config from the profile.
RunConfig configFor(Profile p, ModeId modeId, {DateTime? now}) {
  final mode = modeById(modeId);
  var seed = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
  var modifier = Modifier.none;
  if (modeId == ModeId.dailyTournament) {
    seed = dailySeed(now ?? DateTime.now());
    modifier = dailyModifier(seed);
  }
  final s = p.settings;
  return RunConfig(
    mode: mode,
    seed: seed,
    modifier: modifier,
    bag: List.of(p.bag),
    clubLevels: Map.of(p.clubLevels),
    caddieId: p.equippedCaddie != null && p.caddiesUnlocked.contains(p.equippedCaddie) ? p.equippedCaddie : null,
    gridSize: 4 + p.clubhouseLevel('grid'),
    startingCoins: 60 + 20 * p.clubhouseLevel('coins'),
    bonusClubhouseHp: 20.0 * p.clubhouseLevel('walls'),
    aimAssist: s.aimAssist,
    autoCaddie: s.autoCaddie,
    // Hidden, capped adaptation: about 10% fewer enemies after 2 losses in a row.
    enemyCountScale: p.lossStreak >= 2 ? 0.9 : 1,
    tutorial: p.firstRun,
  );
}

class Rewards {
  const Rewards({required this.coins, required this.tokens, required this.xp, this.unlockedCaddie});

  final int coins;
  final int tokens;
  final int xp;
  final String? unlockedCaddie;
}

Rewards rewardsFor(RunResult r) {
  final win = r.won ? 1 : 0;
  return Rewards(
    coins: r.coinsEarned ~/ 2 + r.holesCleared * 15 + win * 50,
    tokens: r.holesCleared * 3 + r.bestRung + win * 10,
    xp: r.score ~/ 10,
  );
}

/// Applies a finished run to the profile and returns what was granted.
Rewards applyRun(Profile p, RunResult r, {int? dailySeedUsed}) {
  var rewards = rewardsFor(r);
  p.coins += rewards.coins;
  p.clubTokens += rewards.tokens;
  p.xp += rewards.xp;
  p.runsPlayed++;
  p.lossStreak = r.won ? 0 : p.lossStreak + 1;
  for (final e in r.killsById.entries) {
    final id = e.key == 'coyote_pup' ? 'coyote' : e.key;
    p.bestiary[id] = (p.bestiary[id] ?? 0) + e.value;
  }
  if (r.mode == ModeId.suddenDeath) p.bestSuddenDeath = math.max(p.bestSuddenDeath, r.holesCleared);
  if (r.mode == ModeId.dailyTournament && dailySeedUsed != null) {
    if (p.lastDailySeed != dailySeedUsed) p.bestDailyScore = 0;
    p.lastDailySeed = dailySeedUsed;
    p.bestDailyScore = math.max(p.bestDailyScore, r.score);
  }
  // First caddie comes free after the first run (spec 10).
  final first = caddies.firstWhere((c) => c.unlockCoins == 0);
  if (!p.caddiesUnlocked.contains(first.id)) {
    p.caddiesUnlocked.add(first.id);
    p.equippedCaddie ??= first.id;
    rewards = Rewards(coins: rewards.coins, tokens: rewards.tokens, xp: rewards.xp, unlockedCaddie: first.id);
  }
  return rewards;
}

// ------------------------------------------------------------ purchases

bool upgradeClub(Profile p, String clubId) {
  final level = p.clubLevel(clubId);
  final cost = clubUpgradeCost(level);
  if (!p.unlockedClubs.contains(clubId) || level >= maxClubLevel || p.clubTokens < cost) return false;
  p.clubTokens -= cost;
  p.clubLevels[clubId] = level + 1;
  return true;
}

bool unlockClub(Profile p, String clubId) {
  final c = clubById(clubId);
  if (p.unlockedClubs.contains(clubId) || p.clubTokens < c.unlockTokens) return false;
  p.clubTokens -= c.unlockTokens;
  p.unlockedClubs.add(clubId);
  return true;
}

/// Toggles a club in the 3-club bag. The bag never empties and never exceeds 3.
bool toggleBag(Profile p, String clubId) {
  if (!p.unlockedClubs.contains(clubId)) return false;
  if (p.bag.contains(clubId)) {
    if (p.bag.length <= 1) return false;
    p.bag.remove(clubId);
    return true;
  }
  if (p.bag.length >= 3) return false;
  p.bag.add(clubId);
  return true;
}

bool buyClubhouseUpgrade(Profile p, String id) {
  final u = clubhouseUpgradeById(id);
  final level = p.clubhouseLevel(id);
  final cost = u.cost(level);
  if (level >= u.maxLevel || p.coins < cost) return false;
  p.coins -= cost;
  p.clubhouse[id] = level + 1;
  return true;
}

bool unlockCaddie(Profile p, String id) {
  final c = caddieById(id);
  if (p.caddiesUnlocked.contains(id) || p.coins < c.unlockCoins) return false;
  p.coins -= c.unlockCoins;
  p.caddiesUnlocked.add(id);
  return true;
}

/// One unlock the player is working toward.
class NearUnlock {
  const NearUnlock(this.name, this.have, this.need, this.currency);

  final String name;
  final int have;
  final int need;
  final String currency;

  double get progress => need == 0 ? 1 : (have / need).clamp(0.0, 1.0);
}

/// Spec 7a "always-something-close": the three nearest unlocks.
List<NearUnlock> nearestUnlocks(Profile p) {
  final all = <NearUnlock>[
    for (final c in clubs)
      if (!p.unlockedClubs.contains(c.id)) NearUnlock('Unlock ${c.name}', p.clubTokens, c.unlockTokens, 'tokens'),
    for (final id in p.unlockedClubs)
      if (p.clubLevel(id) < maxClubLevel)
        NearUnlock('${clubById(id).name} level ${p.clubLevel(id) + 1}', p.clubTokens, clubUpgradeCost(p.clubLevel(id)), 'tokens'),
    for (final u in clubhouseUpgrades)
      if (p.clubhouseLevel(u.id) < u.maxLevel)
        NearUnlock('${u.name} ${p.clubhouseLevel(u.id) + 1}', p.coins, u.cost(p.clubhouseLevel(u.id)), 'coins'),
    for (final c in caddies)
      if (!p.caddiesUnlocked.contains(c.id) && c.unlockCoins > 0) NearUnlock('Caddie ${c.name}', p.coins, c.unlockCoins, 'coins'),
  ];
  all.sort((a, b) => b.progress.compareTo(a.progress));
  return all.take(3).toList();
}
