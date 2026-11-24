import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fore_last_stand/data/caddies.dart';
import 'package:fore_last_stand/data/commentary.dart';
import 'package:fore_last_stand/data/modes.dart';
import 'package:fore_last_stand/meta/profile.dart';
import 'package:fore_last_stand/meta/progression.dart';
import 'package:fore_last_stand/sim/battle.dart';
import 'package:fore_last_stand/sim/combo.dart';

RunResult result({bool won = true, ModeId mode = ModeId.quickRound, int holes = 5}) => RunResult(
      won: won,
      mode: mode,
      holesCleared: holes,
      kills: 40,
      killsById: const {'goose': 30, 'coyote_pup': 3},
      coinsEarned: 200,
      bestRung: 3,
      underPar: 2,
      score: 1500,
      seconds: 200,
    );

void main() {
  test('profile survives a JSON round trip', () {
    final p = Profile(coins: 10, clubTokens: 5, runsPlayed: 3, equippedCaddie: 'big_earl')
      ..caddiesUnlocked.add('big_earl')
      ..clubLevels['driver'] = 4
      ..clubhouse['grid'] = 1
      ..bestiary['goose'] = 12
      ..settings.gore = GoreLevel.squeakyClean
      ..settings.leftHanded = true;
    final back = Profile.fromJson((jsonDecode(jsonEncode(p.toJson())) as Map).cast<String, Object?>());
    expect(back.coins, 10);
    expect(back.clubLevel('driver'), 4);
    expect(back.clubhouseLevel('grid'), 1);
    expect(back.bestiary['goose'], 12);
    expect(back.equippedCaddie, 'big_earl');
    expect(back.settings.gore, GoreLevel.squeakyClean);
    expect(back.settings.leftHanded, isTrue);
    expect(back.bag, ['driver', 'iron', 'wedge']);
  });

  test('applying a run pays rewards, fills the bestiary and grants the first caddie', () {
    final p = Profile();
    final r = applyRun(p, result());
    expect(p.runsPlayed, 1);
    expect(p.coins, r.coins);
    expect(p.clubTokens, r.tokens);
    expect(p.bestiary['goose'], 30);
    expect(p.bestiary['coyote'], 3, reason: 'pups count toward the Coyote Pack entry');
    expect(r.unlockedCaddie, caddies.first.id);
    expect(p.equippedCaddie, caddies.first.id);
    expect(applyRun(p, result()).unlockedCaddie, isNull);
  });

  test('loss streak drives hidden adaptive difficulty', () {
    final p = Profile();
    applyRun(p, result(won: false));
    expect(configFor(p, ModeId.quickRound).enemyCountScale, 1);
    applyRun(p, result(won: false));
    expect(configFor(p, ModeId.quickRound).enemyCountScale, 0.9);
    applyRun(p, result());
    expect(p.lossStreak, 0);
  });

  test('meta screens unlock gradually', () {
    final p = Profile();
    expect(p.clubhouseUnlocked, isFalse);
    p.runsPlayed = 2;
    expect(p.clubhouseUnlocked, isTrue);
    expect(p.bagUnlocked, isFalse);
    p.runsPlayed = 3;
    expect(p.bagUnlocked, isTrue);
  });

  test('clubhouse upgrades feed the run config', () {
    final p = Profile(coins: 10000);
    expect(buyClubhouseUpgrade(p, 'grid'), isTrue);
    expect(buyClubhouseUpgrade(p, 'grid'), isTrue);
    expect(buyClubhouseUpgrade(p, 'grid'), isFalse, reason: 'max 6x6');
    buyClubhouseUpgrade(p, 'coins');
    buyClubhouseUpgrade(p, 'walls');
    final c = configFor(p, ModeId.fullRound);
    expect(c.gridSize, 6);
    expect(c.startingCoins, 80);
    expect(c.bonusClubhouseHp, 20);
  });

  test('the bag: unlock putter with tokens, keep 1-3 clubs equipped, level up', () {
    final p = Profile(clubTokens: 1000);
    expect(toggleBag(p, 'putter'), isFalse, reason: 'locked');
    expect(unlockClub(p, 'putter'), isTrue);
    expect(toggleBag(p, 'putter'), isFalse, reason: 'bag is full');
    expect(toggleBag(p, 'wedge'), isTrue);
    expect(toggleBag(p, 'putter'), isTrue);
    expect(p.bag, ['driver', 'iron', 'putter']);
    expect(upgradeClub(p, 'driver'), isTrue);
    expect(p.clubLevel('driver'), 2);
    p.bag = ['driver'];
    expect(toggleBag(p, 'driver'), isFalse, reason: 'never empty');
  });

  test('dottie can be hired with coins', () {
    final p = Profile(coins: 1000);
    expect(unlockCaddie(p, 'dottie'), isTrue);
    expect(p.caddiesUnlocked, contains('dottie'));
    expect(p.coins, 600);
  });

  test('nearest unlocks lists three goals sorted by progress', () {
    final near = nearestUnlocks(Profile(clubTokens: 50, coins: 100));
    expect(near, hasLength(3));
    for (var i = 1; i < near.length; i++) {
      expect(near[i].progress, lessThanOrEqualTo(near[i - 1].progress));
    }
  });

  test('daily tournament config uses a date seed and modifier', () {
    final c = configFor(Profile(), ModeId.dailyTournament, now: DateTime.utc(2026, 11, 24));
    expect(c.seed, 20261124);
    expect(c.modifier, isNot(Modifier.none));
    expect(configFor(Profile(), ModeId.dailyTournament, now: DateTime.utc(2026, 11, 24)).seed, c.seed);
  });

  test('daily best score resets on a new day', () {
    final p = Profile();
    applyRun(p, result(mode: ModeId.dailyTournament), dailySeedUsed: 1);
    expect(p.bestDailyScore, 1500);
    applyRun(p, const RunResult(won: false, mode: ModeId.dailyTournament, holesCleared: 1, kills: 1, killsById: {}, coinsEarned: 0, bestRung: 0, underPar: 0, score: 100, seconds: 10), dailySeedUsed: 2);
    expect(p.bestDailyScore, 100);
  });

  test('combo ladder climbs Bogey to Albatross and resets on a miss', () {
    final c = ComboLadder();
    expect(c.name, 'Bogey');
    for (var i = 0; i < 15; i++) {
      c.hit();
    }
    expect(c.name, 'Albatross');
    expect(c.coinMultiplier, 3);
    c.miss();
    expect(c.name, 'Bogey');
    expect(c.bestRung, 4);
  });

  test('commentator avoids repeating recent lines', () {
    var i = 0;
    final c = Commentator((n) => (i++) % n);
    final lines = [for (var k = 0; k < 3; k++) c.line(CommentEvent.sweetSpot)];
    expect(lines.toSet().length, 3);
  });
}
