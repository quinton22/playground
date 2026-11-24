import 'dart:math' as math;

import '../data/caddies.dart';
import '../data/clubs.dart';
import '../data/commentary.dart';
import '../data/courses.dart';
import '../data/enemies.dart';
import '../data/modes.dart';
import '../data/perks.dart';
import '../data/towers.dart';
import 'combo.dart';
import 'entities.dart';
import 'swing_math.dart';
import 'vec.dart';
import 'waves.dart';

/// Board size in world units. The renderer scales this to the screen.
const double worldWidth = 360;
const double worldHeight = 640;

const V2 teePosition = V2(180, 590);
const Box clubhouseBox = Box(112, 604, 248, 640);

/// Plots live in this zone around the clubhouse (spec 4).
const Box baseZone = Box(24, 420, 336, 580);

enum Phase { playing, drafting, building, won, lost }

/// Everything a run needs from the menu and the player's profile.
class RunConfig {
  const RunConfig({
    required this.mode,
    this.seed = 1,
    this.modifier = Modifier.none,
    this.bag = starterBag,
    this.clubLevels = const {},
    this.caddieId,
    this.gridSize = 4,
    this.startingCoins = 60,
    this.bonusClubhouseHp = 0,
    this.aimAssist = 0.3,
    this.autoCaddie = false,
    this.enemyCountScale = 1,
    this.tutorial = false,
    this.course = suburbanMuni,
  });

  final ModeSpec mode;
  final int seed;
  final Modifier modifier;
  final List<String> bag;
  final Map<String, int> clubLevels;
  final String? caddieId;
  final int gridSize;
  final int startingCoins;
  final double bonusClubhouseHp;

  /// 0..1 aim-assist slider (spec 3 accessibility).
  final double aimAssist;

  /// Swings for the player at reduced damage.
  final bool autoCaddie;

  /// Hidden adaptive difficulty: 0.9 after two losses in a row (spec 10).
  final double enemyCountScale;

  /// Scripted first run with hints (spec 10).
  final bool tutorial;
  final CourseSpec course;
}

class RunResult {
  const RunResult({
    required this.won,
    required this.mode,
    required this.holesCleared,
    required this.kills,
    required this.killsById,
    required this.coinsEarned,
    required this.bestRung,
    required this.underPar,
    required this.score,
    required this.seconds,
  });

  final bool won;
  final ModeId mode;
  final int holesCleared;
  final int kills;
  final Map<String, int> killsById;
  final int coinsEarned;
  final int bestRung;
  final int underPar;
  final int score;
  final double seconds;
}

/// The whole in-run simulation. Pure Dart: the Flame layer only draws it and
/// forwards input, so every rule here is unit-testable.
class Battle {
  Battle(this.config)
      : rng = math.Random(config.seed),
        flags = config.mode.flags,
        coins = config.startingCoins {
    commentator = Commentator(rng.nextInt);
    final glass = config.modifier == Modifier.glassClubhouse ? 0.6 : 1.0;
    maxBaseHp = (100 + config.bonusClubhouseHp) * glass;
    baseHp = maxBaseHp;
    clubIndex = 0;
    _startHole();
  }

  final RunConfig config;
  final math.Random rng;
  late final Commentator commentator;

  Phase phase = Phase.playing;
  int holeIndex = 0;
  double holeTime = 0;
  double runTime = 0;
  late HoleSpec hole;
  final List<ScheduledSpawn> _queue = [];

  int coins;
  int coinsEarned = 0;
  int kills = 0;
  final Map<String, int> killsById = {};
  int underParCount = 0;
  int holesCleared = 0;

  int flags;
  late double maxBaseHp;
  late double baseHp;

  /// Larger swarms after each fallen flag (spec 4).
  double swarmScale = 1;

  final List<Enemy> enemies = [];
  final List<Ball> balls = [];
  final List<Tower> towers = [];
  final List<GasCloud> gas = [];
  final List<Fx> fx = [];
  final List<String> perksTaken = [];
  List<PerkSpec> draftOffer = [];
  int rerollsLeft = 1;

  final ComboLadder combo = ComboLadder();
  double foreMeter = 0;
  double foreTimer = 0;
  double _foreVolley = 0;

  late int clubIndex;
  double swingCooldown = 0;
  bool dragging = false;
  double dragTime = 0;

  double caddieCooldown = 0;
  double slowMo = 0;
  double shake = 0;

  String? comment;
  double commentTimer = 0;
  String? hint;

  int _nextId = 0;
  bool _firstKillSaid = false;
  double _tagCommentCooldown = 0;

  // ---------------------------------------------------------------- getters

  ClubSpec get club => clubById(config.bag[clubIndex]);
  CaddieSpec? get caddie => config.caddieId == null ? null : caddieById(config.caddieId!);
  bool get finished => phase == Phase.won || phase == Phase.lost;
  bool get foreReady => foreMeter >= 100 && phase == Phase.playing;
  int get totalHoles => config.mode.holes ?? 0;
  int get gridSize => config.gridSize;
  double get caddieMaxCooldown => (caddie?.cooldown ?? 0) * perkProduct(PerkEffect.caddieCooldown);
  bool get caddieReady => caddie != null && caddieCooldown <= 0 && phase == Phase.playing;
  int get remainingSpawns => _queue.length;
  double get ringPhaseNow => ringPhase(dragTime);

  double perkSum(PerkEffect effect) {
    var sum = 0.0;
    for (final id in perksTaken) {
      final p = perkById(id);
      if (p.effect == effect) sum += p.value;
    }
    return sum;
  }

  /// Repeated reduction perks stack multiplicatively, so they never reach 100%.
  double perkProduct(PerkEffect effect) {
    var product = 1.0;
    for (final id in perksTaken) {
      final p = perkById(id);
      if (p.effect == effect) product *= 1 - p.value;
    }
    return product;
  }

  bool hasPerk(PerkEffect effect) => perksTaken.any((id) => perkById(id).effect == effect);

  int get completedPerkSets {
    final counts = <PerkSet, int>{};
    for (final id in perksTaken) {
      final s = perkById(id).set;
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return counts.values.where((c) => c >= perkSetSize).length;
  }

  double get sweetSpotWidth => 0.16 * (1 + perkSum(PerkEffect.sweetSpotWidth)) * (1 + config.aimAssist * 0.5);

  double get swingCooldownMax {
    final level = config.clubLevels[club.id] ?? 1;
    return baseSwingCooldown * perkProduct(PerkEffect.swingCooldown) * (1 - 0.01 * (level - 1));
  }

  double clubDamage(ClubSpec c) {
    final level = config.clubLevels[c.id] ?? 1;
    var d = c.damage * (1 + 0.05 * (level - 1));
    d *= 1 + perkSum(PerkEffect.ballDamage) + 0.15 * completedPerkSets;
    if (hasPerk(PerkEffect.bouncyBalls)) d *= 0.9;
    return d;
  }

  double get ballRadius => config.modifier == Modifier.bigBalls ? 8 : 5;

  // ---------------------------------------------------------------- plots

  Box plotBox(int col, int row) {
    final w = baseZone.width / gridSize, h = baseZone.height / gridSize;
    return Box(baseZone.left + col * w, baseZone.top + row * h, baseZone.left + (col + 1) * w, baseZone.top + (row + 1) * h);
  }

  double get towerRadius => math.min(baseZone.width, baseZone.height) / gridSize * 0.36;

  /// Plot under a world point, or null.
  (int, int)? plotAt(V2 p) {
    if (!baseZone.contains(p)) return null;
    final col = ((p.x - baseZone.left) / (baseZone.width / gridSize)).floor().clamp(0, gridSize - 1);
    final row = ((p.y - baseZone.top) / (baseZone.height / gridSize)).floor().clamp(0, gridSize - 1);
    return (col, row);
  }

  Tower? towerAt(int col, int row) {
    for (final t in towers) {
      if (!t.removed && t.col == col && t.row == row) return t;
    }
    return null;
  }

  bool get canBuild => phase == Phase.building || phase == Phase.playing;

  int placeCost(TowerSpec spec) {
    var c = spec.cost.toDouble();
    if (config.modifier == Modifier.cheapSeats) c *= 0.75;
    if (phase == Phase.playing) c *= livePlacementMultiplier;
    return c.round();
  }

  int upgradePrice(Tower t) {
    var c = upgradeCost(t.spec, t.level).toDouble();
    if (config.modifier == Modifier.cheapSeats) c *= 0.75;
    if (phase == Phase.playing) c *= livePlacementMultiplier;
    return c.round();
  }

  /// Full refund for re-placement in the build phase or the first 10 s of the hole
  /// it was placed for (spec 4); 70% otherwise.
  int refundFor(Tower t) {
    final free = (phase == Phase.building && t.placedHole == holeIndex + 1) ||
        (phase == Phase.playing && t.placedHole == holeIndex && holeTime <= 10);
    return free ? t.invested : (t.invested * sellRefund).floor();
  }

  bool placeTower(String specId, int col, int row) {
    if (!canBuild || towerAt(col, row) != null || col < 0 || row < 0 || col >= gridSize || row >= gridSize) return false;
    final spec = towerById(specId);
    final cost = placeCost(spec);
    if (coins < cost) return false;
    coins -= cost;
    final live = phase == Phase.playing;
    // Towers placed in the build phase belong to the coming hole.
    final forHole = phase == Phase.building ? holeIndex + 1 : holeIndex;
    towers.add(Tower(
      id: _nextId++,
      spec: spec,
      col: col,
      row: row,
      pos: plotBox(col, row).center,
      invested: cost,
      placedHole: forHole,
      placedLive: live,
    ));
    if (live) slowMo = 2;
    if (config.tutorial && hint != null && hint!.contains('plot')) hint = null;
    return true;
  }

  bool upgradeTower(Tower t) {
    if (!canBuild || t.removed || t.level >= maxTowerLevel) return false;
    final cost = upgradePrice(t);
    if (coins < cost) return false;
    coins -= cost;
    t.invested += cost;
    t.level++;
    t.maxHp = t.spec.health * towerLevelMultiplier(t.level);
    t.hp = t.maxHp;
    if (phase == Phase.playing) slowMo = 2;
    return true;
  }

  int sellTower(Tower t) {
    if (!canBuild || t.removed) return 0;
    final refund = refundFor(t);
    coins += refund;
    towers.remove(t);
    return refund;
  }

  /// Sprinkler + Tee-Tesla on edge-adjacent plots form a pair (spec 4).
  bool hasPair(Tower t) {
    final want = t.spec.kind == TowerKind.teeTesla
        ? TowerKind.sprinkler
        : t.spec.kind == TowerKind.sprinkler
            ? TowerKind.teeTesla
            : null;
    if (want == null) return false;
    for (final o in towers) {
      if (o.removed || o.spec.kind != want) continue;
      if ((o.col - t.col).abs() + (o.row - t.row).abs() == 1) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------- holes

  void _startHole() {
    hole = _holeFor(holeIndex);
    holeTime = 0;
    _queue
      ..clear()
      ..addAll(scheduleHole(hole, math.Random(config.seed * 7919 + holeIndex), countScale: swarmScale * config.enemyCountScale));
    phase = Phase.playing;
    say(CommentEvent.holeStart);
    if (hole.hasBoss) say(CommentEvent.bossArrives, force: true);
    if (config.tutorial && holeIndex == 0) hint = 'Drag back anywhere and release to swing!';
    if (config.tutorial && holeIndex == 3) hint = 'Bank a ball off your own tower to overcharge it.';
  }

  HoleSpec _holeFor(int index) {
    switch (config.mode.id) {
      case ModeId.quickRound:
        const order = [0, 1, 3, 4];
        return index < order.length ? config.course.holes[order[index]] : miniBossHole;
      case ModeId.fullRound:
        return config.course.holes[index];
      case ModeId.suddenDeath:
      case ModeId.dailyTournament:
        // Own RNG per hole so a seed always yields the same holes (Daily Tournament).
        return generateHole(index, math.Random(config.seed * 1000 + index));
    }
  }

  double get _enemyHpScale {
    if (config.mode.endless || config.mode.id == ModeId.dailyTournament) {
      return 1 + 0.07 * math.max(0, holeIndex - 3);
    }
    return 1;
  }

  void _holeCleared() {
    holesCleared++;
    var bonus = hole.coinBonus;
    if (holeTime <= hole.par) {
      bonus += 10 + 2 * holeIndex;
      underParCount++;
      say(CommentEvent.holeUnderPar, force: true);
    } else {
      say(CommentEvent.holeClear, force: true);
    }
    _gainCoins(bonus);
    baseHp = math.min(maxBaseHp, baseHp + maxBaseHp * 0.1);
    balls.clear();
    gas.clear();
    foreTimer = 0;
    if (!config.mode.endless && holesCleared >= totalHoles) {
      phase = Phase.won;
      say(CommentEvent.runWon, force: true);
      return;
    }
    _offerDraft();
    phase = Phase.drafting;
    if (config.tutorial && holeIndex == 1) hint = 'Pick 1 of 3 perks.';
  }

  void _offerDraft() {
    const unique = {
      PerkEffect.explosiveBalls,
      PerkEffect.flamingBalls,
      PerkEffect.frozenBalls,
      PerkEffect.magneticBalls,
      PerkEffect.rubberChicken,
      PerkEffect.sprinklerHeal,
      PerkEffect.sweetSpotDamage,
      PerkEffect.bouncyBalls,
    };
    final pool = perks.where((p) => !(unique.contains(p.effect) && perksTaken.contains(p.id))).toList();
    final offer = <PerkSpec>[];
    while (offer.length < 3 && pool.isNotEmpty) {
      final total = pool.fold<int>(0, (s, p) => s + rarityWeight[p.rarity]!);
      var roll = rng.nextInt(total);
      for (final p in pool) {
        roll -= rarityWeight[p.rarity]!;
        if (roll < 0) {
          offer.add(p);
          pool.remove(p);
          break;
        }
      }
    }
    draftOffer = offer;
  }

  bool reroll() {
    if (phase != Phase.drafting || rerollsLeft <= 0) return false;
    rerollsLeft--;
    _offerDraft();
    return true;
  }

  void pickPerk(int index) {
    if (phase != Phase.drafting || index < 0 || index >= draftOffer.length) return;
    final p = draftOffer[index];
    perksTaken.add(p.id);
    if (p.effect == PerkEffect.clubhouseHealth) {
      maxBaseHp += p.value;
      baseHp = maxBaseHp;
    }
    draftOffer = [];
    phase = Phase.building;
    if (config.tutorial && towers.isEmpty) hint = 'Tap a glowing plot to build a tower, then Tee Off.';
  }

  /// Leaves the build phase and starts the next hole.
  void teeOff() {
    if (phase != Phase.building) return;
    holeIndex++;
    hint = null;
    _startHole();
  }

  // ---------------------------------------------------------------- input

  void cycleClub() => clubIndex = (clubIndex + 1) % config.bag.length;

  void selectClub(int i) {
    if (i >= 0 && i < config.bag.length) clubIndex = i;
  }

  void beginSwing() {
    dragging = true;
    dragTime = 0;
  }

  void cancelSwing() => dragging = false;

  /// Releases a drag-back swing. [dragDx]/[dragDy] are in world units.
  /// Returns the ball launched, or null if no swing happened.
  Ball? releaseSwing(double dragDx, double dragDy) {
    final phaseAtRelease = ringPhaseNow;
    dragging = false;
    if (phase != Phase.playing || swingCooldown > 0) return null;
    final s = swingFromDrag(dragDx, dragDy);
    if (s == null) return null;
    final sweet = isSweetSpot(phaseAtRelease, width: sweetSpotWidth);
    return _swing(_assistedDirection(s.direction), s.power, sweet: sweet);
  }

  bool _clubCanHit(ClubSpec c, Enemy e) => c.canHitFliers || !e.flier;

  /// Aim-assisted direction, considering only enemies the current club can hit.
  V2 _assistedDirection(V2 dir) {
    final target = _nearestEnemy(teePosition, (e) => _clubCanHit(club, e));
    return target == null ? dir : assistAim(dir, target.pos - teePosition, config.aimAssist);
  }

  /// Where a Wedge lob from [from] lands.
  static double wedgeDistance(double power) => 120 + 360 * power;

  static V2 lobTargetFor(V2 from, V2 dir, double power) {
    final dist = wedgeDistance(power);
    return V2((from.x + dir.x * dist).clamp(0, worldWidth).toDouble(), (from.y + dir.y * dist).clamp(0, worldHeight).toDouble());
  }

  /// The path the dotted aim preview draws for a drag, using the same assisted
  /// direction and club rules as [releaseSwing]. Empty if the drag is not a swing.
  List<V2> aimPreview(double dragDx, double dragDy) {
    final s = swingFromDrag(dragDx, dragDy);
    if (s == null) return const [];
    final dir = _assistedDirection(s.direction);
    if (club.kind == ClubKind.wedge) return [teePosition, lobTargetFor(teePosition, dir, s.power)];
    final bounces = club.bounces + perkSum(PerkEffect.extraBounce).round() + (hasPerk(PerkEffect.bouncyBalls) ? 2 : 0);
    return previewPath(teePosition, dir, 140 + 260 * s.power, worldWidth, maxBounces: bounces > 0 ? 1 : 0);
  }

  Ball _swing(V2 dir, double power, {required bool sweet, bool auto = false}) {
    swingCooldown = swingCooldownMax;
    final c = club;
    var damage = clubDamage(c);
    if (sweet) {
      damage *= sweetSpotDamageMultiplier + perkSum(PerkEffect.sweetSpotDamage);
      shake = 0.25;
      fx.add(Fx(FxKind.sweet, [teePosition], ttl: 0.35, radius: 30, colorValue: 0xFF76FF03));
      say(CommentEvent.sweetSpot);
    }
    if (auto) damage *= 0.6;
    if (config.tutorial && hint != null && hint!.startsWith('Drag')) hint = null;
    final ball = _launch(c, teePosition, dir, power, damage, sweet: sweet);
    return ball;
  }

  Ball _launch(ClubSpec c, V2 from, V2 dir, double power, double damage, {bool sweet = false, bool free = false}) {
    final speed = c.speed * (0.4 + 0.6 * power);
    final extraBounce = perkSum(PerkEffect.extraBounce).round() + (hasPerk(PerkEffect.bouncyBalls) ? 2 : 0);
    final ball = Ball(
      club: c,
      pos: from,
      vel: dir * speed,
      damage: damage,
      pierce: c.pierce + perkSum(PerkEffect.extraPierce).round() + (sweet ? 1 : 0),
      bounces: c.bounces + extraBounce,
      radius: ballRadius,
      sweet: sweet,
      free: free,
    );
    if (c.kind == ClubKind.wedge) {
      ball.lobStart = from;
      ball.lobTarget = lobTargetFor(from, dir, power);
      ball.lobTotal = (ball.lobTarget!.distanceTo(from) / c.speed) + 0.35;
    }
    balls.add(ball);
    return ball;
  }

  bool triggerFore() {
    if (!foreReady) return false;
    foreMeter = 0;
    foreTimer = 3;
    _foreVolley = 0;
    shake = 0.3;
    say(CommentEvent.foreBurst, force: true);
    return true;
  }

  bool useCaddie() {
    final cd = caddie;
    if (cd == null || !caddieReady) return false;
    caddieCooldown = caddieMaxCooldown;
    switch (cd.active) {
      case CaddieActive.bigDrive:
        final ball = Ball(
          club: clubById('driver'),
          pos: teePosition,
          vel: const V2(0, -650),
          damage: cd.activePower * (1 + perkSum(PerkEffect.ballDamage)),
          pierce: 999,
          bounces: 0,
          radius: 16,
          free: true,
          mega: true,
        );
        balls.add(ball);
        shake = 0.3;
      case CaddieActive.markAndSnipe:
        Enemy? best;
        for (final e in enemies) {
          if (!e.alive) continue;
          if (best == null || e.hp > best.hp) best = e;
        }
        if (best != null) {
          best.markTimer = 6;
          fx.add(Fx(FxKind.tracer, [teePosition, best.pos], ttl: 0.3, colorValue: cd.colorValue));
          damageEnemy(best, cd.activePower);
        }
    }
    return true;
  }

  // ---------------------------------------------------------------- update

  /// Advances the simulation by [realDt] seconds.
  void update(double realDt) {
    if (finished) return;
    final dt0 = realDt.clamp(0.0, 0.05);
    for (final f in fx) {
      f.ttl -= dt0;
    }
    fx.removeWhere((f) => f.ttl <= 0);
    if (commentTimer > 0) {
      commentTimer -= dt0;
      if (commentTimer <= 0) comment = null;
    }
    shake = math.max(0, shake - dt0);
    if (phase != Phase.playing) return;

    final slowed = slowMo > 0;
    slowMo = math.max(0, slowMo - dt0);
    final dt = slowed ? dt0 * 0.3 : dt0;
    if (dragging) dragTime += dt0;

    holeTime += dt;
    runTime += dt;
    swingCooldown = math.max(0, swingCooldown - dt);
    caddieCooldown = math.max(0, caddieCooldown - dt);
    _tagCommentCooldown = math.max(0, _tagCommentCooldown - dt);

    _spawnDue();
    _updateFore(dt);
    if (config.autoCaddie && swingCooldown <= 0) _autoSwing();
    for (final g in gas) {
      g.time -= dt;
    }
    gas.removeWhere((g) => g.time <= 0);
    _updateTowers(dt);
    _updateEnemies(dt);
    if (phase != Phase.playing) return;
    _updateBalls(dt);
    if (phase != Phase.playing) return;

    enemies.removeWhere((e) => e.removed || e.hp <= 0);
    balls.removeWhere((b) => b.done);
    towers.removeWhere((t) => t.removed);

    if (_queue.isEmpty && enemies.isEmpty) _holeCleared();
  }

  void _spawnDue() {
    while (_queue.isNotEmpty && _queue.first.time <= holeTime) {
      final s = _queue.removeAt(0);
      spawnEnemy(s.enemyId, s.edge);
    }
  }

  V2 _spawnPoint(SpawnEdge edge) {
    switch (edge) {
      case SpawnEdge.top:
        return V2(20 + rng.nextDouble() * (worldWidth - 40), -20);
      case SpawnEdge.left:
        return V2(-20, 30 + rng.nextDouble() * 300);
      case SpawnEdge.right:
        return V2(worldWidth + 20, 30 + rng.nextDouble() * 300);
      case SpawnEdge.sides:
        return _spawnPoint(rng.nextBool() ? SpawnEdge.left : SpawnEdge.right);
      case SpawnEdge.any:
        return _spawnPoint(const [SpawnEdge.top, SpawnEdge.left, SpawnEdge.right][rng.nextInt(3)]);
      case SpawnEdge.water:
        final water = config.course.water;
        if (water.isEmpty) return _spawnPoint(SpawnEdge.top);
        final w = water[rng.nextInt(water.length)];
        return V2(w.left + rng.nextDouble() * w.width, w.top + rng.nextDouble() * w.height);
    }
  }

  Enemy spawnEnemy(String id, SpawnEdge edge, {V2? at, Enemy? leader}) {
    final spec = enemyById(id);
    var hp = spec.health * _enemyHpScale;
    if (spec.boss) hp *= hole.bossScale;
    final e = Enemy(id: _nextId++, spec: spec, pos: at ?? _spawnPoint(edge), maxHp: hp, leader: leader);
    enemies.add(e);
    if (spec.ability == EnemyAbility.packLeader) {
      for (var i = 0; i < 3; i++) {
        final offset = V2((i - 1) * 22.0, -18.0 - 8 * (i % 2));
        spawnEnemy('coyote_pup', edge, at: e.pos + offset, leader: e);
      }
    }
    return e;
  }

  void _updateFore(double dt) {
    if (foreTimer <= 0) return;
    foreTimer -= dt;
    _foreVolley -= dt;
    if (_foreVolley > 0) return;
    _foreVolley = 0.3;
    var c = club;
    if (c.kind == ClubKind.wedge) c = clubById('iron');
    final n = 5 + perkSum(PerkEffect.foreFanBalls).round();
    final cd = caddie;
    final passive = cd != null && cd.passive == CaddiePassive.foreBurstDamage ? cd.passiveValue : 0.0;
    final dmg = clubDamage(c) * (1 + passive);
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + (-0.95 + 1.9 * i / math.max(1, n - 1));
      _launch(c, teePosition, V2(math.cos(a), math.sin(a)), 1, dmg, free: true);
    }
  }

  void _autoSwing() {
    final target = _nearestEnemy(teePosition, (e) => _clubCanHit(club, e));
    if (target == null) return;
    final to = target.pos - teePosition;
    // Wedge lands at wedgeDistance(power), so invert that for lobs.
    final power = club.kind == ClubKind.wedge
        ? ((to.length - wedgeDistance(0)) / (wedgeDistance(1) - wedgeDistance(0))).clamp(0.0, 1.0)
        : (to.length / 400).clamp(0.3, 1.0);
    _swing(to.normalized(), power, sweet: false, auto: true);
  }

  Enemy? _nearestEnemy(V2 from, bool Function(Enemy) ok, {double range = double.infinity}) {
    Enemy? best;
    var bestD = range;
    for (final e in enemies) {
      if (!e.alive || !ok(e)) continue;
      final d = e.pos.distanceTo(from);
      if (d < bestD) {
        bestD = d;
        best = e;
      }
    }
    return best;
  }

  Tower? _nearestTower(V2 from) {
    Tower? best;
    var bestD = double.infinity;
    for (final t in towers) {
      if (t.removed) continue;
      final d = t.pos.distanceTo(from);
      if (d < bestD) {
        bestD = d;
        best = t;
      }
    }
    return best;
  }

  // ---------------------------------------------------------------- enemies

  void _updateEnemies(double dt) {
    for (final e in List.of(enemies)) {
      if (finished) return;
      if (!e.alive) continue;
      e.age += dt;
      e.hitFlash = math.max(0, e.hitFlash - dt);
      e.markTimer = math.max(0, e.markTimer - dt);
      e.wetTimer = math.max(0, e.wetTimer - dt);
      e.slowTimer = math.max(0, e.slowTimer - dt);
      e.abilityTimer -= dt;
      if (e.burnTimer > 0) {
        e.burnTimer -= dt;
        damageEnemy(e, e.burnDps * dt, quiet: true);
        if (!e.alive) continue;
      }
      _enemyAbility(e);
      if (!e.alive) continue;
      _moveEnemy(e, dt);
    }
  }

  void _enemyAbility(Enemy e) {
    switch (e.spec.ability) {
      case EnemyAbility.honk:
        if (e.abilityTimer <= 0) {
          final near = towers.where((t) => !t.removed && t.pos.distanceTo(e.pos) < 70).toList();
          if (near.isNotEmpty) {
            for (final t in near) {
              t.stun = 2;
            }
            e.abilityTimer = 5;
            fx.add(Fx(FxKind.honk, [e.pos], ttl: 0.5, radius: 70, colorValue: 0xFFFFFFFF));
          }
        }
      case EnemyAbility.gas:
        if (!e.gasUsed && e.pos.y > baseZone.top - 50) {
          e.gasUsed = true;
          gas.add(GasCloud(e.pos + const V2(0, 40), 70, 4));
        }
      case EnemyAbility.summonFlock:
        if (e.abilityTimer <= 0) {
          final mini = hole.bossScale < 1;
          e.abilityTimer = mini ? 8 : 6;
          final n = mini ? 2 : 3;
          for (var i = 0; i < n; i++) {
            spawnEnemy('goose', SpawnEdge.top, at: e.pos + V2((i - (n - 1) / 2) * 30, 20));
          }
          fx.add(Fx(FxKind.honk, [e.pos], ttl: 0.6, radius: 60, colorValue: 0xFFFFD54F));
        }
      default:
        break;
    }
  }

  double _speedOf(Enemy e) {
    var s = e.spec.speed;
    if (config.modifier == Modifier.stampede) s *= 1.25;
    if (e.leader != null && e.leader!.alive) s *= 1.25;
    if (e.spec.ability == EnemyAbility.charge) {
      if (e.chargeDir != null) s *= 3;
      return s; // ignores slows
    }
    if (e.slowTimer > 0) s *= 1 - e.slowAmount;
    if (e.spec.id == 'gator' && e.age < 1) s *= 0.2; // surfacing
    return s;
  }

  void _moveEnemy(Enemy e, double dt) {
    final clubhouse = clubhouseBox.center;
    V2 target;
    switch (e.spec.ability) {
      case EnemyAbility.diveTowers:
      case EnemyAbility.bomber:
        target = _nearestTower(e.pos)?.pos ?? clubhouse;
      case EnemyAbility.thief:
        target = e.fleeing ? V2(e.pos.x, -60) : clubhouse;
      default:
        target = clubhouse;
    }

    // Boar locks a straight-line charge once it is lined up.
    if (e.spec.ability == EnemyAbility.charge && e.chargeDir == null && e.pos.y > 180) {
      e.chargeDir = (clubhouse - e.pos).normalized();
    }
    final dir = e.chargeDir ?? (target - e.pos).normalized();
    e.pos = e.pos + dir * (_speedOf(e) * dt) + e.push * dt;
    e.push = e.push * math.max(0, 1 - 6 * dt);

    // Contact with towers.
    if (e.spec.ability == EnemyAbility.diveTowers || e.spec.ability == EnemyAbility.bomber) {
      final t = _nearestTower(e.pos);
      if (t != null && t.pos.distanceTo(e.pos) < towerRadius + e.radius) {
        if (e.spec.ability == EnemyAbility.bomber) {
          for (final o in towers) {
            if (o.pos.distanceTo(e.pos) < 45) o.hp -= 30;
          }
          fx.add(Fx(FxKind.explosion, [e.pos], ttl: 0.4, radius: 45, colorValue: 0xFFFF6D00));
        } else {
          t.hp -= 15;
          fx.add(Fx(FxKind.gib, [t.pos], ttl: 0.3, colorValue: 0xFF263238));
        }
        e.removed = true;
        return;
      }
    }

    // Raccoons steal on reaching the base zone, then run off the top.
    if (e.spec.ability == EnemyAbility.thief) {
      if (!e.fleeing && e.pos.y > baseZone.top) {
        e.stolen = math.min(coins, 15);
        coins -= e.stolen;
        e.fleeing = true;
        if (e.stolen > 0) {
          fx.add(Fx(FxKind.text, [e.pos], ttl: 0.8, text: '-${e.stolen}', colorValue: 0xFFFFEB3B));
          say(CommentEvent.coinsStolen);
        }
      } else if (e.fleeing && e.pos.y < -30) {
        e.removed = true;
      }
      return;
    }

    if (clubhouseBox.intersectsCircle(e.pos, e.radius)) {
      e.removed = true;
      damageBase(e.spec.baseDamage);
    }
  }

  void damageBase(double amount) {
    if (finished) return;
    baseHp -= amount;
    shake = math.max(shake, 0.2);
    if (baseHp > 0) return;
    flags--;
    say(CommentEvent.flagLost, force: true);
    if (flags <= 0) {
      baseHp = 0;
      phase = Phase.lost;
      say(CommentEvent.runLost, force: true);
      return;
    }
    baseHp = maxBaseHp * 0.3;
    swarmScale += 0.15;
  }

  /// Applies damage with all multipliers. [lightning] gets the wet bonus.
  void damageEnemy(Enemy e, double amount, {bool lightning = false, bool quiet = false}) {
    if (!e.alive) return;
    var m = 1.0;
    if (lightning && e.wetTimer > 0) m *= 1.5;
    if (e.markTimer > 0) m *= 1.25;
    final cd = caddie;
    if (e.isBoss && cd != null && cd.passive == CaddiePassive.bossDamage) m *= 1 + cd.passiveValue;
    if (e.leader != null && e.leader!.alive) m *= 0.7;
    e.hp -= amount * m;
    if (!quiet) e.hitFlash = 0.1;
    if (e.hp <= 0) _kill(e);
  }

  void _kill(Enemy e) {
    e.hp = 0;
    e.removed = true;
    kills++;
    killsById[e.spec.id] = (killsById[e.spec.id] ?? 0) + 1;
    var reward = e.spec.coins * combo.coinMultiplier * (1 + perkSum(PerkEffect.coinGain));
    if (config.modifier == Modifier.glassClubhouse) reward *= 1.5;
    _gainCoins(reward.round());
    // Recovered coins go back to the purse but were never newly earned.
    coins += e.stolen;
    fx.add(Fx(FxKind.gib, [e.pos], ttl: e.isBoss ? 1.2 : 0.7, radius: e.radius, colorValue: e.spec.colorValue));
    if (!_firstKillSaid) {
      _firstKillSaid = true;
      say(CommentEvent.firstKill, force: true);
    }
    if (e.isBoss) shake = 0.6;
  }

  void _gainCoins(int n) {
    coins += n;
    coinsEarned += n;
  }

  // ---------------------------------------------------------------- towers

  void _updateTowers(double dt) {
    final rate = 1 + perkSum(PerkEffect.towerFireRate);
    for (final t in towers) {
      if (t.removed) continue;
      t.stun = math.max(0, t.stun - dt);
      t.overcharge = math.max(0, t.overcharge - dt);
      t.gassed = gas.any((g) => g.pos.distanceTo(t.pos) < g.radius);
      if (!t.active) continue;
      final over = t.overcharge > 0;
      final lvl = towerLevelMultiplier(t.level);
      t.cooldown -= dt * rate * (over && t.spec.kind == TowerKind.ballMachine ? 2.5 : 1);
      switch (t.spec.kind) {
        case TowerKind.ballMachine:
          if (t.cooldown > 0) break;
          final e = _nearestEnemy(t.pos, (_) => true, range: t.spec.range);
          if (e == null) break;
          t.cooldown = t.spec.fireInterval;
          fx.add(Fx(FxKind.tracer, [t.pos, e.pos], ttl: 0.08, colorValue: 0xFFFFFFFF));
          damageEnemy(e, t.spec.damage * lvl);
        case TowerKind.sprinkler:
          t.spin += dt * 3;
          if (t.cooldown > 0) break;
          t.cooldown = 0.5;
          final range = t.spec.range * (over ? 1.5 : 1);
          if (hasPerk(PerkEffect.sprinklerHeal)) {
            baseHp = math.min(maxBaseHp, baseHp + perkSum(PerkEffect.sprinklerHeal) * 0.5);
          }
          fx.add(Fx(FxKind.splash, [t.pos], ttl: 0.4, radius: range, colorValue: 0x554FC3F7));
          for (final e in enemies) {
            if (!e.alive || e.flier || e.pos.distanceTo(t.pos) > range) continue;
            e.wetTimer = 2;
            e.slowTimer = 0.6;
            e.slowAmount = math.max(e.slowAmount, 0.4);
            damageEnemy(e, t.spec.damage * lvl * 0.5, quiet: true);
          }
        case TowerKind.teeTesla:
          if (t.cooldown > 0) break;
          final first = _nearestEnemy(t.pos, (_) => true, range: t.spec.range);
          if (first == null) break;
          t.cooldown = t.spec.fireInterval;
          final jumps = 3 + (hasPair(t) ? 2 : 0) + (over ? 2 : 0) + (t.level - 1);
          final chain = <Enemy>[first];
          var cur = first;
          while (chain.length < jumps) {
            final next = _nearestEnemy(cur.pos, (e) => !chain.contains(e), range: 90);
            if (next == null) break;
            chain.add(next);
            cur = next;
          }
          fx.add(Fx(FxKind.lightning, [t.pos, ...chain.map((e) => e.pos)], ttl: 0.2, colorValue: 0xFFFFF176));
          for (final e in chain) {
            damageEnemy(e, t.spec.damage * lvl, lightning: true);
          }
        case TowerKind.ripper:
          t.spin += dt * (over ? 24 : 10);
          final dps = t.spec.damage * lvl * (over ? 2 : 1);
          for (final e in List.of(enemies)) {
            if (!e.alive || e.flier || e.pos.distanceTo(t.pos) > t.spec.range + e.radius) continue;
            damageEnemy(e, dps * dt, quiet: true);
            e.hitFlash = 0.05;
          }
        case TowerKind.cartCannon:
          if (t.cooldown > 0) break;
          Enemy? best;
          var bestScore = -1;
          for (final e in enemies) {
            if (!e.alive || e.flier || e.pos.distanceTo(t.pos) > t.spec.range) continue;
            final score = enemies.where((o) => o.alive && o.pos.distanceTo(e.pos) < 50).length;
            if (score > bestScore) {
              bestScore = score;
              best = e;
            }
          }
          if (best == null) break;
          t.cooldown = t.spec.fireInterval;
          final at = best.pos;
          fx.add(Fx(FxKind.explosion, [at], ttl: 0.35, radius: 50, colorValue: 0xFFCE93D8));
          for (final e in List.of(enemies)) {
            if (e.alive && !e.flier && e.pos.distanceTo(at) < 50) damageEnemy(e, t.spec.damage * lvl);
          }
        case TowerKind.sniper:
          if (t.cooldown > 0) break;
          Enemy? best;
          for (final e in enemies) {
            if (!e.alive || e.pos.distanceTo(t.pos) > t.spec.range) continue;
            if (best == null || (e.isBoss && !best.isBoss) || (e.isBoss == best.isBoss && e.hp > best.hp)) best = e;
          }
          if (best == null) break;
          t.cooldown = t.spec.fireInterval;
          if (best.isBoss || best.spec.ability == EnemyAbility.packLeader) best.markTimer = 4;
          fx.add(Fx(FxKind.tracer, [t.pos, best.pos], ttl: 0.15, colorValue: 0xFFA5D6A7));
          damageEnemy(best, t.spec.damage * lvl);
      }
    }
  }

  /// A ball hit one of the player's towers: overcharge it (spec 3/4).
  void _tagTower(Tower t, Ball b) {
    t.overcharge = 3 + perkSum(PerkEffect.overchargeDuration);
    if (t.spec.kind == TowerKind.cartCannon && b.sweet) t.cooldown = 0;
    fx.add(Fx(FxKind.sweet, [t.pos], ttl: 0.3, radius: towerRadius + 8, colorValue: 0xFFFFEB3B));
    if (_tagCommentCooldown <= 0) {
      _tagCommentCooldown = 6;
      say(CommentEvent.towerTag);
    }
  }

  // ---------------------------------------------------------------- balls

  void _updateBalls(double dt) {
    final magnet = perkSum(PerkEffect.magneticBalls);
    for (final b in balls) {
      if (b.done) continue;
      b.life -= dt;
      if (b.life <= 0) {
        _endBall(b);
        continue;
      }
      if (b.isLob) {
        b.lobTime += dt;
        final p = (b.lobTime / b.lobTotal).clamp(0.0, 1.0);
        b.pos = b.lobStart! + (b.lobTarget! - b.lobStart!) * p;
        if (p >= 1) _landLob(b);
        continue;
      }
      if (b.club.kind == ClubKind.putter) {
        b.vel = b.vel * math.max(0, 1 - 0.55 * dt);
        if (b.vel.length < 60) {
          _endBall(b);
          continue;
        }
      }
      if (magnet > 0 && !b.mega) {
        final e = _nearestEnemy(b.pos, (e) => b.club.canHitFliers || !e.flier, range: 150);
        if (e != null) {
          final speed = b.vel.length;
          final want = (e.pos - b.pos).normalized() * speed;
          b.vel = (b.vel + (want - b.vel) * math.min(1, magnet * dt)).normalized() * speed;
        }
      }
      if (config.modifier == Modifier.windy) b.vel = b.vel + const V2(45, 0) * dt;
      // Substeps of at most one ball radius so fast balls can't skip past contacts.
      final steps = math.max(1, (b.vel.length * dt / math.max(2.0, b.radius)).ceil());
      final step = dt / steps;
      for (var i = 0; i < steps && !b.done; i++) {
        b.pos = b.pos + b.vel * step;
        _ballWalls(b);
        if (b.done) break;
        _ballTowers(b);
        if (b.done) break;
        _ballEnemies(b);
      }
    }
  }

  void _ballWalls(Ball b) {
    V2? normal;
    if (b.pos.x < b.radius && b.vel.x < 0) normal = const V2(1, 0);
    if (b.pos.x > worldWidth - b.radius && b.vel.x > 0) normal = const V2(-1, 0);
    if (b.pos.y < b.radius && b.vel.y < 0) normal = const V2(0, 1);
    if (normal != null && b.bounces > 0) {
      b.bounces--;
      b.vel = b.vel.reflect(normal);
      return;
    }
    const m = 30.0;
    if (b.pos.x < -m || b.pos.x > worldWidth + m || b.pos.y < -m || b.pos.y > worldHeight + m) _endBall(b);
  }

  void _ballTowers(Ball b) {
    if (b.mega) return;
    for (final t in towers) {
      if (t.removed || t.id == b.lastTowerId) continue;
      final d = b.pos - t.pos;
      if (d.length > towerRadius + b.radius) continue;
      b.lastTowerId = t.id;
      _tagTower(t, b);
      if (b.bounces > 0) {
        b.bounces--;
        final n = d.normalized();
        b.vel = b.vel.reflect(n);
        b.pos = t.pos + n * (towerRadius + b.radius + 0.5);
      } else {
        _endBall(b);
      }
      return;
    }
  }

  void _ballEnemies(Ball b) {
    for (final e in List.of(enemies)) {
      if (!e.alive || b.hitIds.contains(e.id)) continue;
      if (e.flier && !b.club.canHitFliers && !b.mega) continue;
      if (e.pos.distanceTo(b.pos) > e.radius + b.radius) continue;
      b.hitIds.add(e.id);
      _ballHit(b, e);
      if (b.pierce > 0) {
        b.pierce--;
        continue;
      }
      if (b.bounces > 0) {
        b.bounces--;
        b.vel = b.vel.reflect((b.pos - e.pos).normalized());
        continue;
      }
      _endBall(b);
      return;
    }
  }

  void _ballHit(Ball b, Enemy e) {
    b.hitSomething = true;
    damageEnemy(e, b.damage);
    _onHitPerks(b, e.pos, e);
    _registerHit(b);
  }

  void _onHitPerks(Ball b, V2 at, Enemy? e) {
    final splash = perkSum(PerkEffect.explosiveBalls);
    if (splash > 0) {
      fx.add(Fx(FxKind.explosion, [at], ttl: 0.25, radius: 32, colorValue: 0xFFFFAB40));
      for (final o in List.of(enemies)) {
        if (o != e && o.alive && o.pos.distanceTo(at) < 32) damageEnemy(o, b.damage * splash, quiet: true);
      }
    }
    if (e == null || !e.alive) return;
    if (hasPerk(PerkEffect.flamingBalls)) {
      e.burnTimer = 3;
      e.burnDps = perkSum(PerkEffect.flamingBalls);
    }
    if (hasPerk(PerkEffect.frozenBalls) && e.spec.ability != EnemyAbility.charge) {
      e.slowTimer = 2;
      e.slowAmount = math.max(e.slowAmount, perkSum(PerkEffect.frozenBalls));
    }
    if (hasPerk(PerkEffect.rubberChicken) && !e.isBoss) {
      e.push = e.push + b.vel.normalized() * perkSum(PerkEffect.rubberChicken) * 4;
    }
  }

  void _registerHit(Ball b) {
    final climbed = combo.hit();
    foreMeter = math.min(100, foreMeter + combo.foreCharge * (1 + perkSum(PerkEffect.foreCharge)));
    if (climbed && combo.rung >= 2) {
      say(CommentEvent.combo);
      fx.add(Fx(FxKind.text, [teePosition - const V2(0, 60)], ttl: 1, text: '${combo.name}!', colorValue: 0xFFFFEB3B));
    }
  }

  void _landLob(Ball b) {
    final at = b.lobTarget!;
    final radius = b.club.blastRadius * (b.sweet ? 1.3 : 1);
    fx.add(Fx(FxKind.explosion, [at], ttl: 0.35, radius: radius, colorValue: 0xFFFFF59D));
    var hitAny = false;
    for (final e in List.of(enemies)) {
      if (!e.alive || e.flier || e.pos.distanceTo(at) > radius + e.radius) continue;
      hitAny = true;
      damageEnemy(e, b.damage);
      _onHitPerks(b, at, e);
    }
    for (final t in towers) {
      if (!t.removed && t.pos.distanceTo(at) < towerRadius + 6) _tagTower(t, b);
    }
    if (hitAny) {
      b.hitSomething = true;
      _registerHit(b);
    }
    _endBall(b);
  }

  void _endBall(Ball b) {
    if (b.done) return;
    b.done = true;
    if (!b.hitSomething && !b.free) combo.miss();
  }

  // ---------------------------------------------------------------- misc

  void say(CommentEvent event, {bool force = false}) {
    if (!force && commentTimer > 1.5) return;
    comment = commentator.line(event);
    commentTimer = 3;
  }

  RunResult result() => RunResult(
        won: phase == Phase.won,
        mode: config.mode.id,
        holesCleared: holesCleared,
        kills: kills,
        killsById: Map.of(killsById),
        coinsEarned: coinsEarned,
        bestRung: combo.bestRung,
        underPar: underParCount,
        score: kills * 10 + holesCleared * 100 + underParCount * 50 + combo.bestRung * 25 + (phase == Phase.won ? 500 : 0),
        seconds: runTime,
      );
}
