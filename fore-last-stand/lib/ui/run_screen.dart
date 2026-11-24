import 'package:flame/game.dart';
import 'package:material_ui/material_ui.dart';

import '../data/clubs.dart';
import '../data/modes.dart';
import '../data/perks.dart';
import '../data/towers.dart';
import '../game/fore_game.dart';
import '../meta/profile_store.dart';
import '../meta/progression.dart';
import '../sim/battle.dart';
import '../sim/combo.dart';
import '../sim/entities.dart';
import '../sim/vec.dart';
import 'results_screen.dart';

class RunScreen extends StatefulWidget {
  const RunScreen({super.key, required this.store, required this.config});

  final ProfileStore store;
  final RunConfig config;

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  late final Battle battle = Battle(widget.config);
  late final ForeGame game = ForeGame(battle, widget.store.profile.settings);
  Offset? _dragStart;
  bool _paused = false;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    game.hudTick.addListener(_onTick);
  }

  @override
  void dispose() {
    game.hudTick.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (battle.finished && !_ended) {
      _ended = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    }
  }

  void _finish() {
    if (!mounted) return;
    final result = battle.result();
    final daily = widget.config.mode.id == ModeId.dailyTournament ? widget.config.seed : null;
    final rewards = widget.store.update((p) => applyRun(p, result, dailySeedUsed: daily));
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultsScreen(store: widget.store, result: result, rewards: rewards, config: widget.config),
      ),
    );
  }

  void _quit() {
    battle.phase = Phase.lost;
    _ended = true;
    _finish();
  }

  // ---------------------------------------------------------------- input

  void _onPanStart(DragStartDetails d) {
    if (battle.phase != Phase.playing || _paused) return;
    _dragStart = d.localPosition;
    game.aimDrag = V2.zero;
    battle.beginSwing();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final s = _dragStart;
    if (s == null) return;
    final delta = (d.localPosition - s) / game.scale;
    game.aimDrag = V2(delta.dx, delta.dy);
  }

  void _onPanEnd(DragEndDetails d) {
    final drag = game.aimDrag;
    _dragStart = null;
    game.aimDrag = null;
    if (drag == null) {
      battle.cancelSwing();
      return;
    }
    battle.releaseSwing(drag.x, drag.y);
  }

  void _onTapUp(TapUpDetails d) {
    if (_paused || !battle.canBuild) return;
    final plot = battle.plotAt(game.toWorld(d.localPosition));
    setState(() => game.selectedPlot = plot);
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final leftHanded = widget.store.profile.settings.leftHanded;
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: game.hudTick,
          builder: (context, _, child) => Column(
            children: [
              _TopBar(battle: battle, onPause: _pause),
              Expanded(
                child: Stack(
                  children: [
                    child!,
                    if (battle.comment != null || battle.hint != null)
                      Positioned(
                        top: 8,
                        left: 12,
                        right: 12,
                        child: _Ticker(comment: battle.comment, hint: battle.hint),
                      ),
                    if (battle.phase == Phase.drafting)
                      Positioned.fill(
                        child: _DraftPanel(battle: battle, onChanged: () => setState(() {})),
                      ),
                    if (game.selectedPlot != null && battle.canBuild)
                      Positioned(
                        left: 8,
                        right: 8,
                        top: 8,
                        bottom: 8,
                        // Bounded by the board; the sheet scrolls if it is taller.
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: _TowerSheet(
                            battle: battle,
                            plot: game.selectedPlot!,
                            onClose: () => setState(() => game.selectedPlot = null),
                          ),
                        ),
                      ),
                    if (_paused)
                      Positioned.fill(
                        child: _PauseMenu(onResume: _resume, onQuit: _quit),
                      ),
                  ],
                ),
              ),
              // Fixed-height bar under the board so controls never cover a plot.
              SizedBox(
                height: 84,
                child: switch (battle.phase) {
                  Phase.playing => _Controls(battle: battle, leftHanded: leftHanded, onChanged: () => setState(() {})),
                  Phase.building => _BuildBar(battle: battle, onTeeOff: () => setState(battle.teeOff)),
                  _ => const SizedBox.shrink(),
                },
              ),
            ],
          ),
          child: Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              onPanCancel: () {
                _dragStart = null;
                game.aimDrag = null;
                battle.cancelSwing();
              },
              onTapUp: _onTapUp,
              child: GameWidget(game: game),
            ),
          ),
        ),
      ),
    );
  }

  void _pause() {
    setState(() => _paused = true);
    game.pauseEngine();
  }

  void _resume() {
    setState(() => _paused = false);
    game.resumeEngine();
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.battle, required this.onPause});

  final Battle battle;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final total = battle.config.mode.endless ? '∞' : '${battle.totalHoles}';
    final hpFrac = (battle.baseHp / battle.maxBaseHp).clamp(0.0, 1.0);
    return Container(
      color: const Color(0x99000000),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hole ${battle.holeIndex + 1}/$total'
                    '${battle.hole.breather ? '  (breather)' : ''}'
                    '  Par ${battle.hole.par.round()}s  ${battle.holeTime.floor()}s',
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('🚩' * battle.flags),
                      const SizedBox(width: 6),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: hpFrac,
                          minHeight: 6,
                          color: hpFrac > 0.4 ? Colors.lightGreenAccent : Colors.redAccent,
                          backgroundColor: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('🪙 ${battle.coins}'),
                Text(
                  '${battle.combo.name} x${battle.combo.coinMultiplier}',
                  style: TextStyle(color: battle.combo.rung >= 2 ? Colors.yellowAccent : Colors.white70, fontSize: 12),
                ),
              ],
            ),
            IconButton(
              onPressed: onPause,
              icon: const Icon(Icons.pause, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ticker extends StatelessWidget {
  const _Ticker({this.comment, this.hint});

  final String? comment;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        children: [
          if (hint != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.amber.shade700, borderRadius: BorderRadius.circular(8)),
              child: Text(
                hint!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          if (comment != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '🎙 $comment',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic, shadows: [Shadow(blurRadius: 4)]),
              ),
            ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.battle, required this.leftHanded, required this.onChanged});

  final Battle battle;
  final bool leftHanded;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final caddie = battle.caddie;
    final children = <Widget>[
      Expanded(
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          alignment: leftHanded ? WrapAlignment.end : WrapAlignment.start,
          children: [
            for (var i = 0; i < battle.config.bag.length; i++)
              ChoiceChip(
                label: Text(clubById(battle.config.bag[i]).name),
                selected: battle.clubIndex == i,
                visualDensity: VisualDensity.compact,
                onSelected: (_) {
                  battle.selectClub(i);
                  onChanged();
                },
              ),
          ],
        ),
      ),
      if (caddie != null) ...[
        _RoundButton(
          label: caddie.activeName,
          color: Color(caddie.colorValue),
          fill: battle.caddieMaxCooldown == 0 ? 1 : 1 - battle.caddieCooldown / battle.caddieMaxCooldown,
          enabled: battle.caddieReady,
          onTap: () {
            battle.useCaddie();
            onChanged();
          },
        ),
        const SizedBox(width: 8),
      ],
      _RoundButton(
        label: 'FORE!',
        color: Colors.deepOrange,
        fill: battle.foreMeter / 100,
        enabled: battle.foreReady,
        big: true,
        onTap: () {
          battle.triggerFore();
          onChanged();
        },
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(children: leftHanded ? children.reversed.toList() : children),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.label,
    required this.color,
    required this.fill,
    required this.enabled,
    required this.onTap,
    this.big = false,
  });

  final String label;
  final Color color;
  final double fill;
  final bool enabled;
  final VoidCallback onTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? 74.0 : 58.0;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(value: fill.clamp(0.0, 1.0), strokeWidth: 5, color: color, backgroundColor: Colors.black38),
            ),
            Container(
              width: size - 12,
              height: size - 12,
              decoration: BoxDecoration(shape: BoxShape.circle, color: enabled ? color : Colors.black45),
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: big ? 15 : 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const Map<PerkRarity, Color> rarityColors = {
  PerkRarity.common: Color(0xFF90A4AE),
  PerkRarity.rare: Color(0xFF42A5F5),
  PerkRarity.epic: Color(0xFFAB47BC),
  PerkRarity.legendary: Color(0xFFFFB300),
};

class _DraftPanel extends StatelessWidget {
  const _DraftPanel({required this.battle, required this.onChanged});

  final Battle battle;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xCC000000),
      alignment: Alignment.center,
      // Scrolls when the perk history or large text outgrows the board.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Hole ${battle.holeIndex + 1} cleared!',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text('Mulligan card: pick 1 of 3', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            for (var i = 0; i < battle.draftOffer.length; i++)
              Card(
                color: const Color(0xFF263238),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: rarityColors[battle.draftOffer[i].rarity]!, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  title: Text(
                    battle.draftOffer[i].name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${battle.draftOffer[i].description}\n${battle.draftOffer[i].rarity.name} · ${battle.draftOffer[i].set.name} set',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  isThreeLine: true,
                  onTap: () {
                    battle.pickPerk(i);
                    onChanged();
                  },
                ),
              ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: battle.rerollsLeft > 0
                  ? () {
                      battle.reroll();
                      onChanged();
                    }
                  : null,
              icon: const Icon(Icons.refresh),
              label: Text('Reroll (${battle.rerollsLeft} free)'),
            ),
            if (battle.perksTaken.isNotEmpty)
              Text(
                'Your perks: ${battle.perksTaken.map((id) => perkById(id).name).join(', ')}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

class _BuildBar extends StatelessWidget {
  const _BuildBar({required this.battle, required this.onTeeOff});

  final Battle battle;
  final VoidCallback onTeeOff;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xEE263238),
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            const Expanded(
              child: Text('Build phase: tap a plot to place, upgrade or sell towers.', style: TextStyle(color: Colors.white)),
            ),
            FilledButton(onPressed: onTeeOff, child: Text('Tee Off: hole ${battle.holeIndex + 2}')),
          ],
        ),
      ),
    );
  }
}

class _TowerSheet extends StatelessWidget {
  const _TowerSheet({required this.battle, required this.plot, required this.onClose});

  final Battle battle;
  final (int, int) plot;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tower = battle.towerAt(plot.$1, plot.$2);
    final live = battle.phase == Phase.playing;
    return Card(
      color: const Color(0xF0263238),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tower == null ? 'Empty plot' : '${tower.spec.name}  (level ${tower.level})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  Text('🪙 ${battle.coins}'),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
              if (live) const Text('Live build: double cost, 2 s slow-motion.', style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
              if (tower == null) ..._placeOptions(context) else ..._towerOptions(tower),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _placeOptions(BuildContext context) => [
    for (final spec in towers)
      ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: Color(spec.colorValue),
          child: Text(spec.badge, style: const TextStyle(fontSize: 12)),
        ),
        title: Text(spec.name, style: const TextStyle(color: Colors.white)),
        subtitle: Text('${spec.role}. ${spec.synergy}.', style: const TextStyle(color: Colors.white60, fontSize: 12)),
        trailing: Text(
          '🪙 ${battle.placeCost(spec)}',
          style: TextStyle(color: battle.coins >= battle.placeCost(spec) ? Colors.white : Colors.white38),
        ),
        enabled: battle.coins >= battle.placeCost(spec),
        onTap: () {
          if (battle.placeTower(spec.id, plot.$1, plot.$2)) onClose();
        },
      ),
  ];

  List<Widget> _towerOptions(Tower tower) {
    final canUp = tower.level < maxTowerLevel;
    final price = battle.upgradePrice(tower);
    return [
      Text('${tower.spec.role}. ${tower.spec.synergy}.', style: const TextStyle(color: Colors.white70, fontSize: 12)),
      if (battle.hasPair(tower))
        const Text('Pair bonus active: +2 chain jumps.', style: TextStyle(color: Colors.yellowAccent, fontSize: 12)),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: canUp && battle.coins >= price
                  ? () {
                      battle.upgradeTower(tower);
                      onClose();
                    }
                  : null,
              child: Text(canUp ? 'Upgrade 🪙 $price' : 'Max level'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                battle.sellTower(tower);
                onClose();
              },
              child: Text('Sell +${battle.refundFor(tower)}', style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    ];
  }
}

class _PauseMenu extends StatelessWidget {
  const _PauseMenu({required this.onResume, required this.onQuit});

  final VoidCallback onResume;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xCC000000),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Paused',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Combo rungs: ${ComboLadder.rungNames.join(' → ')}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 20),
          FilledButton(onPressed: onResume, child: const Text('Resume')),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onQuit,
            child: const Text('Concede round', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
