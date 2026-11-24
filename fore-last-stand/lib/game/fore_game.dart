import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show HSVColor;

import '../data/enemies.dart';
import '../data/towers.dart';
import '../meta/profile.dart';
import '../sim/battle.dart';
import '../sim/entities.dart';
import '../sim/swing_math.dart';
import '../sim/vec.dart';

/// Flame layer: runs the [Battle] loop and draws it. Input arrives from the
/// Flutter widget around it (see `RunScreen`), already converted to world units.
class ForeGame extends FlameGame {
  ForeGame(this.battle, this.settings);

  final Battle battle;
  final Settings settings;

  /// Ticks whenever the HUD should rebuild.
  final ValueNotifier<int> hudTick = ValueNotifier(0);

  /// Current drag-back vector in world units while aiming, or null.
  V2? aimDrag;

  /// Plot highlighted by the build sheet.
  (int, int)? selectedPlot;

  double _hudAccumulator = 0;
  Phase _lastPhase = Phase.playing;
  double _time = 0;

  double get scale => size.x <= 0 ? 1 : math.min(size.x / worldWidth, size.y / worldHeight);
  Offset get origin => Offset((size.x - worldWidth * scale) / 2, (size.y - worldHeight * scale) / 2);

  /// Converts a point in widget coordinates to world coordinates.
  V2 toWorld(Offset local) => V2((local.dx - origin.dx) / scale, (local.dy - origin.dy) / scale);

  @override
  Color backgroundColor() => const Color(0xFF2E7D32);

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    battle.update(dt);
    _hudAccumulator += dt;
    if (_hudAccumulator > 0.1 || battle.phase != _lastPhase) {
      _hudAccumulator = 0;
      _lastPhase = battle.phase;
      hudTick.value++;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.save();
    var o = origin;
    if (settings.screenShake && battle.shake > 0) {
      final m = battle.shake * 10;
      o = o.translate(math.sin(_time * 90) * m, math.cos(_time * 77) * m);
    }
    canvas.translate(o.dx, o.dy);
    canvas.scale(scale);
    canvas.clipRect(const Rect.fromLTWH(0, 0, worldWidth, worldHeight));
    _drawCourse(canvas);
    _drawGas(canvas);
    _drawTowers(canvas);
    _drawEnemies(canvas);
    _drawBalls(canvas);
    _drawCooldown(canvas);
    _drawAim(canvas);
    _drawFx(canvas);
    canvas.restore();
  }

  // ------------------------------------------------------------------ course

  static Rect _r(Box b) => Rect.fromLTRB(b.left, b.top, b.right, b.bottom);
  static Offset _o(V2 v) => Offset(v.x, v.y);

  void _drawCourse(Canvas canvas) {
    final stripe = Paint()..color = const Color(0xFF388E3C);
    for (var y = 0.0; y < worldHeight; y += 80) {
      canvas.drawRect(Rect.fromLTWH(0, y, worldWidth, 40), stripe);
    }
    final water = Paint()..color = const Color(0xFF29B6F6);
    for (final w in battle.config.course.water) {
      canvas.drawRRect(RRect.fromRectAndRadius(_r(w), const Radius.circular(18)), water);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(_r(baseZone).inflate(6), const Radius.circular(12)),
      Paint()..color = const Color(0xFF66BB6A),
    );
    final building = battle.phase == Phase.building;
    final glow = building && battle.config.tutorial && battle.towers.isEmpty;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = glow ? 2 + math.sin(_time * 6).abs() * 2 : 1
      ..color = glow ? const Color(0xFFFFF176) : const Color(0x55FFFFFF);
    for (var c = 0; c < battle.gridSize; c++) {
      for (var r = 0; r < battle.gridSize; r++) {
        final rect = _r(battle.plotBox(c, r)).deflate(2);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), line);
        if (selectedPlot == (c, r)) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(6)),
            Paint()..color = const Color(0x55FFFFFF),
          );
        }
      }
    }
    // Clubhouse with its flags.
    canvas.drawRRect(
      RRect.fromRectAndRadius(_r(clubhouseBox), const Radius.circular(6)),
      Paint()..color = const Color(0xFF8D6E63),
    );
    final roof = Path()
      ..moveTo(clubhouseBox.left - 6, clubhouseBox.top + 4)
      ..lineTo(clubhouseBox.center.x, clubhouseBox.top - 12)
      ..lineTo(clubhouseBox.right + 6, clubhouseBox.top + 4)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFF5D4037));
    for (var i = 0; i < battle.config.mode.flags; i++) {
      final x = clubhouseBox.left + 14 + i * 16.0;
      final up = i < battle.flags;
      canvas.drawLine(Offset(x, clubhouseBox.top - 2), Offset(x, clubhouseBox.top - 22), Paint()..color = const Color(0xFFEEEEEE));
      canvas.drawRect(
        Rect.fromLTWH(x, clubhouseBox.top - 22, 10, 7),
        Paint()..color = up ? const Color(0xFFE53935) : const Color(0x44000000),
      );
    }
    // Tee.
    canvas.drawCircle(_o(teePosition), 9, Paint()..color = const Color(0xFFA5D6A7));
    canvas.drawCircle(_o(teePosition), 5, Paint()..color = const Color(0xFFFFFFFF));
  }

  void _drawGas(Canvas canvas) {
    for (final g in battle.gas) {
      canvas.drawCircle(_o(g.pos), g.radius, Paint()..color = Color.fromRGBO(156, 204, 101, 0.35 * math.min(1, g.time)));
    }
  }

  // ------------------------------------------------------------------ towers

  void _drawTowers(Canvas canvas) {
    final r = battle.towerRadius;
    for (final t in battle.towers) {
      if (t.removed) continue;
      // Pair link.
      if (t.spec.kind == TowerKind.teeTesla && battle.hasPair(t)) {
        for (final o in battle.towers) {
          if (o.spec.kind == TowerKind.sprinkler && (o.col - t.col).abs() + (o.row - t.row).abs() == 1) {
            canvas.drawLine(_o(t.pos), _o(o.pos), Paint()
              ..color = const Color(0xAAFFF176)
              ..strokeWidth = 3);
          }
        }
      }
      if (t.overcharge > 0) {
        canvas.drawCircle(_o(t.pos), r + 5 + math.sin(_time * 20) * 2, Paint()..color = const Color(0x66FFEB3B));
      }
      var color = Color(t.spec.colorValue);
      if (!t.active) color = Color.lerp(color, const Color(0xFF616161), 0.6)!;
      final rect = Rect.fromCircle(center: _o(t.pos), radius: r);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(r * 0.3)), Paint()..color = color);
      if (t.spec.kind == TowerKind.ripper || t.spec.kind == TowerKind.sprinkler) {
        canvas.save();
        canvas.translate(t.pos.x, t.pos.y);
        canvas.rotate(t.spin);
        final blade = Paint()
          ..color = const Color(0xDDFFFFFF)
          ..strokeWidth = 2.5;
        canvas.drawLine(Offset(-r, 0), Offset(r, 0), blade);
        canvas.drawLine(Offset(0, -r), Offset(0, r), blade);
        canvas.restore();
      }
      _label(canvas, t.spec.badge, t.pos, 11, const Color(0xFF000000));
      for (var i = 0; i < t.level; i++) {
        canvas.drawCircle(Offset(t.pos.x - r + 4 + i * 6, t.pos.y + r - 4), 2, Paint()..color = const Color(0xFFFFFFFF));
      }
      if (t.hp < t.maxHp) _bar(canvas, t.pos - V2(0, r + 5), r * 2, t.hp / t.maxHp, const Color(0xFF64B5F6));
      if (t.stun > 0) _label(canvas, 'zz', t.pos - V2(0, r + 12), 10, const Color(0xFFFFFFFF));
    }
  }

  // ------------------------------------------------------------------ enemies

  void _drawEnemies(Canvas canvas) {
    for (final e in battle.enemies) {
      if (!e.alive) continue;
      final surfacing = e.spec.id == 'gator' && e.age < 1;
      var color = Color(e.spec.colorValue);
      if (e.wetTimer > 0) color = Color.lerp(color, const Color(0xFF4FC3F7), 0.35)!;
      if (e.hitFlash > 0) color = const Color(0xFFFFFFFF);
      if (surfacing) color = color.withValues(alpha: 0.3 + 0.7 * e.age);
      final paint = Paint()..color = color;
      final c = _o(e.pos);
      final rad = e.radius;
      if (e.flier) {
        canvas.drawOval(Rect.fromCenter(center: c.translate(0, rad + 10), width: rad * 1.6, height: rad * 0.6), Paint()..color = const Color(0x33000000));
      }
      switch (e.spec.shape) {
        case EnemyShape.circle:
          canvas.drawCircle(c, rad, paint);
        case EnemyShape.square:
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCircle(center: c, radius: rad), Radius.circular(rad * 0.35)), paint);
        case EnemyShape.triangle:
          canvas.drawPath(
            Path()
              ..moveTo(c.dx, c.dy + rad)
              ..lineTo(c.dx - rad, c.dy - rad * 0.8)
              ..lineTo(c.dx + rad, c.dy - rad * 0.8)
              ..close(),
            paint,
          );
        case EnemyShape.diamond:
          canvas.drawPath(
            Path()
              ..moveTo(c.dx, c.dy - rad)
              ..lineTo(c.dx + rad, c.dy)
              ..lineTo(c.dx, c.dy + rad)
              ..lineTo(c.dx - rad, c.dy)
              ..close(),
            paint,
          );
      }
      // Dark outline + initial so enemies never read as golf balls.
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xCC000000);
      switch (e.spec.shape) {
        case EnemyShape.circle:
          canvas.drawCircle(c, rad, outline);
        case EnemyShape.square:
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCircle(center: c, radius: rad), Radius.circular(rad * 0.35)), outline);
        case EnemyShape.triangle:
        case EnemyShape.diamond:
          break;
      }
      if (!e.isBoss) {
        final dark = Color(e.spec.colorValue).computeLuminance() > 0.4;
        _label(canvas, e.spec.name[0], e.pos, rad, dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF));
      }
      if (e.isBoss) {
        // Crown.
        final top = c.dy - rad - 2;
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 12, top)
            ..lineTo(c.dx - 12, top - 10)
            ..lineTo(c.dx - 6, top - 4)
            ..lineTo(c.dx, top - 12)
            ..lineTo(c.dx + 6, top - 4)
            ..lineTo(c.dx + 12, top - 10)
            ..lineTo(c.dx + 12, top)
            ..close(),
          Paint()..color = const Color(0xFFFFC107),
        );
      }
      if (e.leader != null && e.leader!.alive) {
        canvas.drawCircle(c, rad + 3, Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0x88FF8A65));
      }
      if (e.burnTimer > 0) {
        canvas.drawCircle(c, rad + 2, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFFF7043));
      }
      if (e.markTimer > 0) {
        final m = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFFF1744);
        canvas.drawCircle(c, rad + 5, m);
        canvas.drawLine(c.translate(-rad - 8, 0), c.translate(rad + 8, 0), m);
        canvas.drawLine(c.translate(0, -rad - 8), c.translate(0, rad + 8), m);
      }
      if (e.fleeing && e.stolen > 0) _label(canvas, '\$', e.pos - V2(0, rad + 8), 12, const Color(0xFFFFEB3B));
      if (e.hp < e.maxHp) _bar(canvas, e.pos - V2(0, rad + 6), math.max(20, rad * 2), e.hp / e.maxHp, const Color(0xFFE53935));
    }
  }

  // ------------------------------------------------------------------ balls

  void _drawBalls(Canvas canvas) {
    final white = Paint()..color = const Color(0xFFFFFFFF);
    for (final b in battle.balls) {
      if (b.done) continue;
      if (b.isLob) {
        final h = b.lobHeight * 60;
        canvas.drawCircle(_o(b.pos), b.radius, Paint()..color = const Color(0x55000000));
        canvas.drawCircle(_o(b.pos - V2(0, h)), b.radius * (1 + b.lobHeight * 0.6), white);
        canvas.drawCircle(_o(b.lobTarget!), b.club.blastRadius, Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0x55FFFFFF));
        continue;
      }
      if (b.sweet || b.mega) {
        canvas.drawLine(_o(b.pos), _o(b.pos - b.vel.normalized() * (b.mega ? 40 : 18)), Paint()
          ..color = b.mega ? const Color(0xAAFF7043) : const Color(0xAA76FF03)
          ..strokeWidth = b.radius * 1.4
          ..strokeCap = StrokeCap.round);
      }
      canvas.drawCircle(_o(b.pos), b.radius, white);
    }
  }

  /// Radial recharge indicator around the tee: a dim track plus an arc that
  /// fills clockwise as the swing cooldown runs out. Hidden once ready.
  void _drawCooldown(Canvas canvas) {
    if (battle.phase != Phase.playing || battle.swingCooldown <= 0) return;
    final max = battle.swingCooldownMax;
    if (max <= 0) return;
    final fill = (1 - battle.swingCooldown / max).clamp(0.0, 1.0);
    const r = 16.0;
    final rect = Rect.fromCircle(center: _o(teePosition), radius: r);
    canvas.drawCircle(_o(teePosition), 9, Paint()..color = const Color(0x88000000));
    canvas.drawCircle(_o(teePosition), r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0x44FFFFFF));
    canvas.drawArc(rect, -math.pi / 2, fill * 2 * math.pi, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(const Color(0xFFFF7043), const Color(0xFF76FF03), fill)!);
  }

  void _drawAim(Canvas canvas) {
    final drag = aimDrag;
    if (!battle.dragging || drag == null || battle.phase != Phase.playing) return;
    final swing = swingFromDrag(drag.x, drag.y);
    // Timing ring with its green Sweet Spot zone.
    const ringR = 26.0;
    final ringRect = Rect.fromCircle(center: _o(teePosition), radius: ringR);
    canvas.drawCircle(_o(teePosition), ringR, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0x66FFFFFF));
    final w = battle.sweetSpotWidth;
    canvas.drawArc(ringRect, -math.pi / 2 + (0.5 - w / 2) * 2 * math.pi, w * 2 * math.pi, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = const Color(0xFF76FF03));
    final a = -math.pi / 2 + battle.ringPhaseNow * 2 * math.pi;
    canvas.drawCircle(Offset(teePosition.x + math.cos(a) * ringR, teePosition.y + math.sin(a) * ringR), 4.5, Paint()..color = const Color(0xFFFFFFFF));
    if (swing == null) return;
    final path = battle.aimPreview(drag.x, drag.y);
    if (path.isEmpty) return;
    if (battle.club.blastRadius > 0) {
      canvas.drawCircle(_o(path.last), battle.club.blastRadius, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0x99FFFFFF));
    }
    final dot = Paint()..color = battle.swingCooldown > 0 ? const Color(0x66FFFFFF) : const Color(0xDDFFFFFF);
    for (var i = 0; i < path.length - 1; i++) {
      final a0 = path[i], a1 = path[i + 1];
      final seg = a1 - a0;
      final n = (seg.length / 12).floor();
      for (var k = 0; k <= n; k++) {
        canvas.drawCircle(_o(a0 + seg * (k / math.max(1, n))), 2, dot);
      }
    }
  }

  // ------------------------------------------------------------------ fx

  void _drawFx(Canvas canvas) {
    for (final f in battle.fx) {
      final p = f.progress;
      final color = Color(f.colorValue);
      switch (f.kind) {
        case FxKind.gib:
          _gibs(canvas, f, p);
        case FxKind.explosion:
          canvas.drawCircle(_o(f.points.first), f.radius * (0.4 + 0.6 * p), Paint()..color = color.withValues(alpha: 0.6 * (1 - p)));
        case FxKind.splash:
        case FxKind.honk:
        case FxKind.sweet:
          canvas.drawCircle(_o(f.points.first), f.radius * (0.3 + 0.7 * p), Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = color.withValues(alpha: (1 - p) * color.a));
        case FxKind.lightning:
          final path = Path()..moveTo(f.points.first.x, f.points.first.y);
          for (var i = 1; i < f.points.length; i++) {
            final a = f.points[i - 1], b = f.points[i];
            final mid = (a + b) / 2 + V2(math.sin(i * 7.0 + _time * 50) * 6, math.cos(i * 5.0 + _time * 40) * 6);
            path
              ..lineTo(mid.x, mid.y)
              ..lineTo(b.x, b.y);
          }
          canvas.drawPath(path, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = color.withValues(alpha: 1 - p));
        case FxKind.tracer:
          canvas.drawLine(_o(f.points[0]), _o(f.points[1]), Paint()
            ..strokeWidth = 1.5
            ..color = color.withValues(alpha: 1 - p));
        case FxKind.text:
          _label(canvas, f.text ?? '', f.points.first - V2(0, 20 * p), 16, color.withValues(alpha: 1 - p * p));
      }
    }
  }

  void _gibs(Canvas canvas, Fx f, double p) {
    final gore = settings.gore;
    final rnd = math.Random(f.hashCode);
    final n = gore == GoreLevel.fullSplat ? 14 : 9;
    for (var i = 0; i < n; i++) {
      final a = rnd.nextDouble() * math.pi * 2;
      final d = (8 + rnd.nextDouble() * 22) * p + f.radius * 0.3;
      final Color c;
      switch (gore) {
        case GoreLevel.fullSplat:
          c = i.isEven ? const Color(0xFFC62828) : Color(f.colorValue);
        case GoreLevel.classic:
          c = Color(f.colorValue);
        case GoreLevel.squeakyClean:
          c = HSVColor.fromAHSV(1, rnd.nextDouble() * 360, 0.7, 1).toColor();
      }
      canvas.drawCircle(
        Offset(f.points.first.x + math.cos(a) * d, f.points.first.y + math.sin(a) * d),
        2.5 * (1 - p) + 0.5,
        Paint()..color = c.withValues(alpha: 1 - p),
      );
    }
  }

  // ------------------------------------------------------------------ helpers

  void _bar(Canvas canvas, V2 center, double width, double fraction, Color color) {
    final rect = Rect.fromCenter(center: _o(center), width: width, height: 3);
    canvas.drawRect(rect, Paint()..color = const Color(0x88000000));
    canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, width * fraction.clamp(0, 1), 3), Paint()..color = color);
  }

  final Map<String, Paragraph> _labelCache = {};

  void _label(Canvas canvas, String text, V2 at, double size, Color color) {
    final key = '$text|$size|${color.toARGB32()}';
    final para = _labelCache.putIfAbsent(key, () {
      if (_labelCache.length > 300) _labelCache.clear();
      final b = ParagraphBuilder(ParagraphStyle(textAlign: TextAlign.center, fontSize: size, fontWeight: FontWeight.bold))
        ..pushStyle(TextStyle(color: color))
        ..addText(text);
      return b.build()..layout(const ParagraphConstraints(width: 120));
    });
    canvas.drawParagraph(para, Offset(at.x - 60, at.y - para.height / 2));
  }
}
