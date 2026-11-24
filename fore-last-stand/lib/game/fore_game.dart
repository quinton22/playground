import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';

import '../data/clubs.dart';
import '../data/enemies.dart';
import 'swing_math.dart';

/// Swing-feel prototype: drag back from the tee, release, hit the animals.
class ForeGame extends FlameGame with DragCallbacks {
  final math.Random _rng = math.Random();
  double _spawnTimer = 0;
  double _swingCooldown = 0;
  Vector2? _dragStart;
  Vector2? _dragNow;
  ClubSpec club = clubs.first;
  int kills = 0;
  int clubhouseFlags = 3;

  Vector2 get tee => Vector2(size.x / 2, size.y - 80);

  @override
  Color backgroundColor() => const Color(0xFF4CAF50);

  @override
  void update(double dt) {
    super.update(dt);
    _swingCooldown = math.max(0, _swingCooldown - dt);
    _spawnTimer -= dt;
    if (_spawnTimer <= 0 && size.x > 0) {
      _spawnTimer = 1.5;
      add(Enemy(enemies[_rng.nextInt(enemies.length)], Vector2(_rng.nextDouble() * size.x, -20)));
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final t = tee;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(t.x, t.y + 40), width: 90, height: 40),
      Paint()..color = const Color(0xFF8D6E63),
    );
    canvas.drawCircle(Offset(t.x, t.y), 6, Paint()..color = const Color(0xFFFFFFFF));
    if (_dragStart != null && _dragNow != null) {
      final swing = swingFromDrag(_dragNow!.x - _dragStart!.x, _dragNow!.y - _dragStart!.y);
      if (swing != null) {
        canvas.drawLine(
          Offset(t.x, t.y),
          Offset(t.x + swing.direction.dx * 200 * swing.power, t.y + swing.direction.dy * 200 * swing.power),
          Paint()
            ..color = const Color(0xCCFFFFFF)
            ..strokeWidth = 3,
        );
      }
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _dragStart = event.localPosition.clone();
    _dragNow = _dragStart!.clone();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    _dragNow = (_dragNow ?? Vector2.zero())..add(event.localDelta);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    final s = _dragStart, n = _dragNow;
    _dragStart = _dragNow = null;
    if (s == null || n == null || _swingCooldown > 0) return;
    final swing = swingFromDrag(n.x - s.x, n.y - s.y);
    if (swing == null) return;
    _swingCooldown = 0.8;
    add(Ball(
      club,
      tee,
      Vector2(swing.direction.dx, swing.direction.dy) * (club.speed * (0.4 + 0.6 * swing.power)),
    ));
  }

  void onEnemyReachedClubhouse() {
    clubhouseFlags = math.max(0, clubhouseFlags - 1);
  }
}

class Ball extends CircleComponent with HasGameReference<ForeGame> {
  Ball(this.club, Vector2 start, this.velocity)
      : _pierceLeft = club.pierce,
        super(radius: 6, position: start, anchor: Anchor.center, paint: Paint()..color = const Color(0xFFFFFFFF));

  final ClubSpec club;
  final Vector2 velocity;
  int _pierceLeft;
  final Set<Enemy> _hit = {};

  @override
  void update(double dt) {
    super.update(dt);
    position += velocity * dt;
    final s = game.size;
    if (position.y < -20 || position.y > s.y + 20 || position.x < -20 || position.x > s.x + 20) {
      removeFromParent();
      return;
    }
    for (final e in game.children.whereType<Enemy>()) {
      if (_hit.contains(e) || e.position.distanceTo(position) > e.radius + radius) continue;
      _hit.add(e);
      e.hurt(club.damage);
      if (_pierceLeft-- <= 0) {
        removeFromParent();
        return;
      }
    }
  }
}

class Enemy extends CircleComponent with HasGameReference<ForeGame> {
  Enemy(this.spec, Vector2 start)
      : health = spec.health,
        super(radius: 14, position: start, anchor: Anchor.center, paint: Paint()..color = Color(spec.colorValue));

  final EnemySpec spec;
  double health;

  void hurt(double amount) {
    health -= amount;
    if (health <= 0) {
      game.kills++;
      removeFromParent();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final target = game.tee;
    final toTarget = target - position;
    if (toTarget.length < 30) {
      game.onEnemyReachedClubhouse();
      removeFromParent();
      return;
    }
    position += toTarget.normalized() * spec.speed * dt;
  }
}
