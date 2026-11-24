import 'package:flutter_test/flutter_test.dart';
import 'package:fore_last_stand/data/courses.dart';
import 'package:fore_last_stand/data/modes.dart';
import 'package:fore_last_stand/data/perks.dart';
import 'package:fore_last_stand/data/towers.dart';
import 'package:fore_last_stand/sim/battle.dart';
import 'package:fore_last_stand/sim/vec.dart';

Battle quick({String? caddie, int coins = 60, List<String> bag = const ['driver', 'iron', 'wedge'], ModeId mode = ModeId.quickRound}) =>
    Battle(RunConfig(mode: modeById(mode), seed: 42, caddieId: caddie, startingCoins: coins, bag: bag, aimAssist: 0));

/// Runs the sim until [cond] or [seconds] elapse.
void runUntil(Battle b, bool Function() cond, {double seconds = 60}) {
  for (var t = 0.0; t < seconds && !cond(); t += 1 / 60) {
    b.update(1 / 60);
  }
}

/// Kills everything on screen and in the queue, as fast as possible.
void clearHole(Battle b) {
  runUntil(b, () {
    for (final e in b.enemies) {
      if (e.alive) b.damageEnemy(e, 1e6);
    }
    return b.phase != Phase.playing;
  }, seconds: 300);
}

void main() {
  test('a run starts on hole 1 with the configured flags and coins', () {
    final b = quick();
    expect(b.phase, Phase.playing);
    expect(b.holeIndex, 0);
    expect(b.flags, 3);
    expect(b.coins, 60);
    expect(b.remainingSpawns, greaterThan(0));
  });

  test('a released drag-back swing launches a ball opposite to the drag', () {
    final b = quick();
    b.beginSwing();
    final ball = b.releaseSwing(0, 100)!;
    expect(ball.vel.y, lessThan(0));
    expect(b.swingCooldown, greaterThan(0));
    // Cooldown blocks the next swing.
    b.beginSwing();
    expect(b.releaseSwing(0, 100), isNull);
  });

  test('releasing in the green zone is a Sweet Spot with +50% damage and +1 pierce', () {
    final b = quick();
    b.beginSwing();
    b.dragTime = 0.5 * 1.1; // ring phase 0.5
    final sweet = b.releaseSwing(0, 100)!;
    expect(sweet.sweet, isTrue);
    expect(sweet.damage, closeTo(10 * 1.5, 1e-9));
    expect(sweet.pierce, 4);

    final b2 = quick();
    b2.beginSwing();
    b2.dragTime = 0.05;
    final normal = b2.releaseSwing(0, 100)!;
    expect(normal.sweet, isFalse);
    expect(normal.damage, closeTo(10, 1e-9));
  });

  test('a driver ball kills a goose in its path and pays coins', () {
    final b = quick();
    final goose = b.spawnEnemy('goose', SpawnEdge.top, at: const V2(180, 400));
    b.beginSwing();
    b.releaseSwing(0, 100);
    runUntil(b, () => !goose.alive, seconds: 2);
    expect(goose.alive, isFalse);
    expect(b.kills, 1);
    expect(b.coins, greaterThan(60));
    expect(b.combo.hits, 1);
  });

  test('a ball that hits nothing breaks the combo', () {
    final b = quick();
    b.combo.hits = 5;
    b.beginSwing();
    b.releaseSwing(100, 0); // fires left into the wall
    runUntil(b, () => b.balls.isEmpty, seconds: 3);
    expect(b.combo.hits, 0);
  });

  test('wedge lobs over enemies and blasts where it lands', () {
    final b = quick();
    b.selectClub(2);
    expect(b.club.id, 'wedge');
    b.beginSwing();
    final ball = b.releaseSwing(0, 80)!;
    expect(ball.isLob, isTrue);
    final target = ball.lobTarget!;
    final a = b.spawnEnemy('gator', SpawnEdge.top, at: target);
    final hp = a.hp;
    runUntil(b, () => ball.done, seconds: 3);
    expect(a.hp, lessThan(hp));
  });

  test('enemies reaching the clubhouse cost HP, then a flag, then the run', () {
    final b = quick();
    b.damageBase(b.maxBaseHp);
    expect(b.flags, 2);
    expect(b.baseHp, closeTo(b.maxBaseHp * 0.3, 1e-9));
    expect(b.swarmScale, greaterThan(1));
    b.damageBase(1000);
    b.damageBase(1000);
    expect(b.phase, Phase.lost);
    expect(b.finished, isTrue);
  });

  test('sudden death has one flag', () {
    final b = quick(mode: ModeId.suddenDeath);
    expect(b.flags, 1);
    b.damageBase(1000);
    expect(b.phase, Phase.lost);
  });

  test('clearing a hole goes to the perk draft, then build, then the next hole', () {
    final b = quick();
    clearHole(b);
    expect(b.phase, Phase.drafting);
    expect(b.holesCleared, 1);
    expect(b.draftOffer, hasLength(3));
    expect(b.draftOffer.map((p) => p.id).toSet(), hasLength(3));
    expect(b.reroll(), isTrue);
    expect(b.reroll(), isFalse, reason: 'one free reroll');
    b.pickPerk(0);
    expect(b.perksTaken, hasLength(1));
    expect(b.phase, Phase.building);
    b.teeOff();
    expect(b.phase, Phase.playing);
    expect(b.holeIndex, 1);
  });

  test('a Quick Round is won after 5 holes, the last with a mini-boss', () {
    final b = quick();
    for (var i = 0; i < 4; i++) {
      clearHole(b);
      b.pickPerk(0);
      b.teeOff();
    }
    expect(b.hole.hasBoss, isTrue);
    expect(b.hole.bossScale, lessThan(1));
    clearHole(b);
    expect(b.phase, Phase.won);
    expect(b.result().won, isTrue);
    expect(b.result().holesCleared, 5);
  });

  test('towers: build-phase cost, live double cost, 70% sell refund, free re-placement', () {
    final b = quick(coins: 500);
    clearHole(b);
    b.pickPerk(0);
    final spec = towerById('ball_machine');
    expect(b.placeTower('ball_machine', 0, 0), isTrue);
    expect(b.coins, greaterThanOrEqualTo(0));
    final t = b.towerAt(0, 0)!;
    // Sold in the same build phase: free re-placement.
    final before = b.coins;
    expect(b.sellTower(t), spec.cost);
    expect(b.coins, before + spec.cost);

    expect(b.placeTower('ball_machine', 1, 1), isTrue);
    b.teeOff();
    runUntil(b, () => b.holeTime > 11, seconds: 15);
    final t2 = b.towerAt(1, 1)!;
    expect(b.refundFor(t2), (spec.cost * sellRefund).floor());
    expect(b.placeCost(spec), spec.cost * 2, reason: 'live placement costs double');
    expect(b.placeTower('ball_machine', 2, 2), isTrue);
    expect(b.slowMo, greaterThan(0), reason: 'live placement slows time');
  });

  test('towers cannot share a plot and upgrades cap at level 3', () {
    final b = quick(coins: 1000);
    expect(b.placeTower('sniper', 0, 0), isTrue);
    expect(b.placeTower('sniper', 0, 0), isFalse);
    final t = b.towerAt(0, 0)!;
    expect(b.upgradeTower(t), isTrue);
    expect(b.upgradeTower(t), isTrue);
    expect(b.upgradeTower(t), isFalse);
    expect(t.level, maxTowerLevel);
  });

  test('a ball machine shoots enemies in range', () {
    final b = quick(coins: 500);
    b.placeTower('ball_machine', 1, 0);
    final t = b.towerAt(1, 0)!;
    final e = b.spawnEnemy('gator', SpawnEdge.top, at: t.pos - const V2(0, 80));
    final hp = e.hp;
    runUntil(b, () => e.hp < hp, seconds: 3);
    expect(e.hp, lessThan(hp));
  });

  test('sprinkler + tee-tesla on adjacent plots form a pair', () {
    final b = quick(coins: 500);
    b.placeTower('sprinkler', 1, 1);
    b.placeTower('tee_tesla', 2, 1);
    b.placeTower('tee_tesla', 3, 3);
    expect(b.hasPair(b.towerAt(2, 1)!), isTrue);
    expect(b.hasPair(b.towerAt(1, 1)!), isTrue);
    expect(b.hasPair(b.towerAt(3, 3)!), isFalse);
  });

  test('wet enemies take +50% lightning damage', () {
    final b = quick();
    final e = b.spawnEnemy('gator', SpawnEdge.top, at: const V2(100, 100));
    b.damageEnemy(e, 10, lightning: true);
    final dry = e.maxHp - e.hp;
    e.wetTimer = 2;
    final before = e.hp;
    b.damageEnemy(e, 10, lightning: true);
    expect(before - e.hp, closeTo(dry * 1.5, 1e-9));
  });

  test('a ball hitting a tower overcharges it', () {
    final b = quick(coins: 500);
    // Plot straight above the tee.
    final plot = b.plotAt(const V2(180, 560))!;
    b.placeTower('ball_machine', plot.$1, plot.$2);
    final t = b.towerAt(plot.$1, plot.$2)!;
    b.beginSwing();
    b.releaseSwing(teePosition.x - t.pos.x, teePosition.y - t.pos.y);
    runUntil(b, () => t.overcharge > 0, seconds: 1);
    expect(t.overcharge, greaterThan(0));
  });

  test('goose honk stuns nearby towers', () {
    final b = quick(coins: 500);
    b.placeTower('sniper', 0, 0);
    final t = b.towerAt(0, 0)!;
    t.cooldown = 99; // hold fire so the goose lives to honk
    final g = b.spawnEnemy('goose', SpawnEdge.top, at: t.pos - const V2(0, 40));
    g.abilityTimer = 0;
    b.update(1 / 60);
    expect(t.stun, greaterThan(0));
  });

  test('raccoons steal coins and return them when killed', () {
    final b = quick(coins: 100);
    final r = b.spawnEnemy('raccoon', SpawnEdge.top, at: V2(30, baseZone.top - 1));
    runUntil(b, () => r.fleeing, seconds: 2);
    expect(r.stolen, 15);
    expect(b.coins, lessThan(100));
    final coins = b.coins;
    b.damageEnemy(r, 1000);
    expect(b.coins, greaterThanOrEqualTo(coins + 15));
  });

  test('squirrel bombers explode on towers', () {
    final b = quick(coins: 500);
    b.placeTower('ripper', 0, 0);
    final t = b.towerAt(0, 0)!;
    t.hp = 25;
    b.spawnEnemy('squirrel', SpawnEdge.top, at: t.pos - const V2(0, 20));
    runUntil(b, () => t.removed, seconds: 2);
    expect(t.removed, isTrue);
  });

  test('skunk gas disables towers', () {
    final b = quick(coins: 500);
    b.placeTower('sniper', 1, 0);
    final t = b.towerAt(1, 0)!;
    t.cooldown = 99;
    b.spawnEnemy('skunk', SpawnEdge.top, at: t.pos - const V2(0, 60));
    runUntil(b, () => b.gas.isNotEmpty, seconds: 1);
    b.update(1 / 60);
    expect(t.gassed, isTrue);
    expect(t.active, isFalse);
  });

  test('coyote leaders bring a pack that is tougher while the leader lives', () {
    final b = quick();
    final leader = b.spawnEnemy('coyote', SpawnEdge.top, at: const V2(180, 100));
    final pups = b.enemies.where((e) => e.leader == leader).toList();
    expect(pups, hasLength(3));
    final pup = pups.first;
    b.damageEnemy(pup, 10);
    expect(pup.maxHp - pup.hp, closeTo(7, 1e-9));
    b.damageEnemy(leader, 1e6);
    final hp = pup.hp;
    b.damageEnemy(pup, 2);
    expect(hp - pup.hp, closeTo(2, 1e-9));
  });

  test('the Fore! burst fires free balls that never break the combo', () {
    final b = quick();
    b.foreMeter = 100;
    expect(b.triggerFore(), isTrue);
    b.update(1 / 60);
    expect(b.balls.length, greaterThanOrEqualTo(5));
    expect(b.balls.every((x) => x.free), isTrue);
    b.combo.hits = 4;
    runUntil(b, () => b.foreTimer <= 0 && b.balls.isEmpty, seconds: 6);
    expect(b.combo.hits, greaterThanOrEqualTo(4));
  });

  test('caddie actives: Big Drive and Mark & Snipe', () {
    final earl = quick(caddie: 'big_earl');
    expect(earl.useCaddie(), isTrue);
    expect(earl.balls.single.mega, isTrue);
    expect(earl.useCaddie(), isFalse, reason: 'on cooldown');

    final dottie = quick(caddie: 'dottie');
    final e = dottie.spawnEnemy('gator', SpawnEdge.top, at: const V2(180, 100));
    expect(dottie.useCaddie(), isTrue);
    expect(e.markTimer, greaterThan(0));
    expect(e.hp, lessThan(e.maxHp));
  });

  test('perks change ball stats', () {
    final b = quick();
    b.perksTaken.addAll(['extra_bounce', 'piercing', 'heavy']);
    b.beginSwing();
    b.dragTime = 0;
    final ball = b.releaseSwing(0, 100)!;
    expect(ball.bounces, 1);
    expect(ball.pierce, 4);
    // +20% Heavy Balls and +15% for completing the ballistics set.
    expect(ball.damage, closeTo(13.5, 1e-9));
  });

  test('three perks from one set grant the set bonus', () {
    final b = quick();
    b.perksTaken.addAll(['extra_bounce', 'piercing', 'heavy']); // all ballistics
    expect(b.completedPerkSets, 1);
  });

  test('daily tournament holes are the same for the same seed', () {
    Battle daily() => Battle(RunConfig(mode: modeById(ModeId.dailyTournament), seed: 20261124, modifier: Modifier.windy));
    final a = daily(), b = daily();
    expect(a.hole.enemyCount, b.hole.enemyCount);
    expect(a.remainingSpawns, b.remainingSpawns);
  });

  test('adaptive difficulty spawns fewer enemies', () {
    final normal = Battle(RunConfig(mode: modeById(ModeId.fullRound), seed: 1));
    final eased = Battle(RunConfig(mode: modeById(ModeId.fullRound), seed: 1, enemyCountScale: 0.5));
    expect(eased.remainingSpawns, lessThan(normal.remainingSpawns));
  });

  test('a simulated full round with an auto-caddie and towers plays without errors', () {
    final b = Battle(RunConfig(mode: modeById(ModeId.fullRound), seed: 7, autoCaddie: true, startingCoins: 400, caddieId: 'dottie'));
    b.placeTower('ball_machine', 1, 0);
    b.placeTower('tee_tesla', 2, 0);
    b.placeTower('sprinkler', 2, 1);
    b.placeTower('cart_cannon', 0, 1);
    b.placeTower('ripper', 3, 1);
    b.placeTower('sniper', 1, 2);
    var t = 0.0;
    while (!b.finished && t < 1200) {
      if (b.phase == Phase.drafting) b.pickPerk(0);
      if (b.phase == Phase.building) b.teeOff();
      if (b.foreReady) b.triggerFore();
      if (b.caddieReady) b.useCaddie();
      b.update(1 / 30);
      t += 1 / 30;
    }
    expect(b.finished, isTrue);
    expect(b.kills, greaterThan(20));
    expect(perks.length, 20);
  });

  group('review fixes', () {
    test('recovered stolen coins are not counted as earned', () {
      final b = quick(coins: 100);
      final r = b.spawnEnemy('raccoon', SpawnEdge.top, at: V2(30, baseZone.top - 1));
      runUntil(b, () => r.fleeing, seconds: 2);
      final earnedBefore = b.coinsEarned;
      b.damageEnemy(r, 1000);
      // Kill reward only (5 coins at Bogey x1), not the 15 recovered.
      expect(b.coinsEarned - earnedBefore, 5);
      expect(b.coins, 105);
    });

    test('repeated cooldown perks never reach zero', () {
      final b = quick(caddie: 'big_earl');
      b.perksTaken.addAll(List.filled(10, 'quick_hands'));
      b.perksTaken.addAll(List.filled(10, 'ace_caddie'));
      expect(b.swingCooldownMax, greaterThan(0));
      expect(b.caddieMaxCooldown, greaterThan(0));
    });

    test('aim assist ignores fliers the club cannot hit', () {
      final b = Battle(RunConfig(mode: modeById(ModeId.quickRound), seed: 42, aimAssist: 1));
      b.enemies.clear();
      b.selectClub(2); // wedge
      // A crow just right of straight up; nothing else on the board.
      b.spawnEnemy('crow', SpawnEdge.top, at: const V2(220, 300));
      final path = b.aimPreview(0, 100);
      expect(path.last.x, closeTo(teePosition.x, 1e-6));
      b.selectClub(0); // driver can hit fliers
      expect(b.aimPreview(0, 100)[1].x, greaterThan(teePosition.x));
    });

    test('wedge preview ends where the lob lands', () {
      final b = quick();
      b.enemies.clear();
      b.selectClub(2);
      final preview = b.aimPreview(30, 160);
      b.beginSwing();
      final ball = b.releaseSwing(30, 160)!;
      expect(preview.last, ball.lobTarget);
    });

    test('nothing changes after the last flag falls', () {
      final b = quick(mode: ModeId.suddenDeath);
      b.enemies.clear();
      for (var i = 0; i < 3; i++) {
        final e = b.spawnEnemy('gator', SpawnEdge.top, at: clubhouseBox.center);
        e.age = 5;
      }
      b.baseHp = 1;
      b.update(1 / 60);
      expect(b.phase, Phase.lost);
      expect(b.flags, 0);
      final kills = b.kills;
      b.update(1 / 60);
      expect(b.kills, kills);
    });

    test('auto-caddie wedge lobs land on the target', () {
      final b = Battle(RunConfig(mode: modeById(ModeId.quickRound), seed: 3, autoCaddie: true, aimAssist: 0));
      b.enemies.clear();
      b.selectClub(2);
      final target = b.spawnEnemy('gator', SpawnEdge.top, at: teePosition - const V2(0, 200));
      target.age = 0; // surfacing: nearly still
      b.update(1 / 60);
      final ball = b.balls.single;
      expect(ball.lobTarget!.distanceTo(target.pos), lessThan(ball.club.blastRadius));
    });

    test('fast balls do not tunnel through enemies at large timesteps', () {
      final b = quick();
      b.enemies.clear();
      // Between two 45-unit steps of a full-power driver (y 500 and 455).
      final goose = b.spawnEnemy('goose', SpawnEdge.top, at: const V2(180, 478));
      goose
        ..abilityTimer = 99
        ..slowTimer = 99
        ..slowAmount = 1; // hold it still
      b.beginSwing();
      b.releaseSwing(0, 1000); // full-power driver
      for (var i = 0; i < 20 && goose.alive; i++) {
        b.update(0.05);
      }
      expect(goose.alive, isFalse);
    });
  });
}
