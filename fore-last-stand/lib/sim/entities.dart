import '../data/clubs.dart';
import '../data/enemies.dart';
import '../data/towers.dart';
import 'vec.dart';

class Enemy {
  Enemy({required this.id, required this.spec, required this.pos, required this.maxHp, this.leader})
      : hp = maxHp;

  final int id;
  final EnemySpec spec;
  V2 pos;
  final double maxHp;
  double hp;
  bool removed = false;

  /// Pack leader for coyote pups.
  final Enemy? leader;

  double slowTimer = 0;
  double slowAmount = 0;
  double wetTimer = 0;
  double burnTimer = 0;
  double burnDps = 0;
  double markTimer = 0;
  double hitFlash = 0;

  /// Honk / summon cooldown.
  double abilityTimer = 2;
  bool gasUsed = false;

  /// Raccoon: coins carried while fleeing.
  int stolen = 0;
  bool fleeing = false;

  /// Boar: locked charge direction.
  V2? chargeDir;

  /// Knock-back velocity that decays.
  V2 push = V2.zero;

  /// Seconds since spawned (gators surface during the first second).
  double age = 0;

  bool get alive => !removed && hp > 0;
  bool get isBoss => spec.boss;
  bool get flier => spec.flier;
  double get radius => spec.radius;
}

class Ball {
  Ball({
    required this.club,
    required this.pos,
    required this.vel,
    required this.damage,
    required this.pierce,
    required this.bounces,
    required this.radius,
    this.sweet = false,
    this.free = false,
    this.mega = false,
  });

  final ClubSpec club;
  V2 pos;
  V2 vel;
  final double damage;
  int pierce;
  int bounces;
  final double radius;
  final bool sweet;

  /// Fore! burst / caddie balls: never break the combo.
  final bool free;

  /// Big Earl's Big Drive.
  final bool mega;

  double life = 3.0;
  bool hitSomething = false;
  bool done = false;
  final Set<int> hitIds = {};
  int lastTowerId = -1;

  // Wedge lob.
  V2? lobStart;
  V2? lobTarget;
  double lobTime = 0;
  double lobTotal = 0;

  bool get isLob => lobTarget != null;

  /// 0..1 height of a lob for rendering.
  double get lobHeight {
    if (!isLob || lobTotal == 0) return 0;
    final p = (lobTime / lobTotal).clamp(0.0, 1.0);
    return 4 * p * (1 - p);
  }
}

class Tower {
  Tower({required this.id, required this.spec, required this.col, required this.row, required this.pos, required this.invested, required this.placedHole, required this.placedLive})
      : hp = spec.health,
        maxHp = spec.health;

  final int id;
  final TowerSpec spec;
  final int col;
  final int row;
  final V2 pos;
  int level = 1;
  double hp;
  double maxHp;
  double cooldown = 0;
  double stun = 0;
  double overcharge = 0;
  bool gassed = false;
  int invested;

  /// Hole index (0-based) when placed, and whether it was placed during play.
  final int placedHole;
  final bool placedLive;

  /// Rotation for rendering spinning things.
  double spin = 0;

  bool get removed => hp <= 0;
  bool get active => !removed && stun <= 0 && !gassed;
}

class GasCloud {
  GasCloud(this.pos, this.radius, this.time);

  final V2 pos;
  final double radius;
  double time;
}

enum FxKind { gib, explosion, lightning, tracer, splash, text, sweet, honk }

/// Short-lived visual effect for the renderer. The simulation never reads these.
class Fx {
  Fx(this.kind, this.points, {this.ttl = 0.4, this.radius = 0, this.colorValue = 0xFFFFFFFF, this.text})
      : maxTtl = ttl;

  final FxKind kind;
  final List<V2> points;
  double ttl;
  final double maxTtl;
  final double radius;
  final int colorValue;
  final String? text;

  double get progress => 1 - (ttl / maxTtl).clamp(0.0, 1.0);
}
