import 'package:material_ui/material_ui.dart';

import '../data/modes.dart';
import '../meta/profile_store.dart';
import '../meta/progression.dart';
import 'bag_screen.dart';
import 'bestiary_screen.dart';
import 'caddies_screen.dart';
import 'clubhouse_screen.dart';
import 'run_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store});

  final ProfileStore store;

  void _play(BuildContext context, ModeId mode) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RunScreen(store: store, config: configFor(store.profile, mode)),
    ));
  }

  void _open(BuildContext context, Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.profile;
        final today = dailySeed(DateTime.now());
        return Scaffold(
          backgroundColor: const Color(0xFF1B5E20),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 12),
                const Text('FORE!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900)),
                const Text('LAST STAND', textAlign: TextAlign.center, style: TextStyle(color: Colors.lightGreenAccent, fontSize: 22, letterSpacing: 6)),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    Chip(label: Text('🪙 ${p.coins}')),
                    Chip(label: Text('🎟 ${p.clubTokens} tokens')),
                    Chip(label: Text('⭐ ${p.xp} XP')),
                  ],
                ),
                const SizedBox(height: 16),
                for (final m in modes)
                  Card(
                    child: ListTile(
                      title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text([
                        '${m.length} · ${m.structure}',
                        if (m.id == ModeId.suddenDeath && p.bestSuddenDeath > 0) 'Best: ${p.bestSuddenDeath} holes',
                        if (m.id == ModeId.dailyTournament) 'Today: ${modifierNames[dailyModifier(today)]}',
                        if (m.id == ModeId.dailyTournament && p.lastDailySeed == today) 'Your best today: ${p.bestDailyScore}',
                      ].join('\n')),
                      trailing: const Icon(Icons.play_arrow),
                      onTap: () => _play(context, m.id),
                    ),
                  ),
                if (p.firstRun)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('New here? Start with a Quick Round.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _NavButton(
                      icon: Icons.sports_golf,
                      label: 'The Bag',
                      lockedText: p.bagUnlocked ? null : 'after 3 rounds',
                      onTap: () => _open(context, BagScreen(store: store)),
                    ),
                    _NavButton(
                      icon: Icons.house,
                      label: 'Clubhouse',
                      lockedText: p.clubhouseUnlocked ? null : 'after 2 rounds',
                      onTap: () => _open(context, ClubhouseScreen(store: store)),
                    ),
                    _NavButton(icon: Icons.person, label: 'Caddies', onTap: () => _open(context, CaddiesScreen(store: store))),
                    _NavButton(icon: Icons.menu_book, label: 'Bestiary', onTap: () => _open(context, BestiaryScreen(store: store))),
                    _NavButton(icon: Icons.settings, label: 'Settings', onTap: () => _open(context, SettingsScreen(store: store))),
                  ],
                ),
                const SizedBox(height: 16),
                for (final u in nearestUnlocks(p))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${u.name}: ${u.have}/${u.need} ${u.currency}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        LinearProgressIndicator(value: u.progress, minHeight: 4),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.label, required this.onTap, this.lockedText});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? lockedText;

  @override
  Widget build(BuildContext context) {
    final locked = lockedText != null;
    return SizedBox(
      width: 104,
      child: FilledButton.tonal(
        onPressed: locked ? null : onTap,
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
        child: Column(children: [
          Icon(locked ? Icons.lock : icon),
          Text(label),
          if (locked) Text(lockedText!, style: const TextStyle(fontSize: 10)),
        ]),
      ),
    );
  }
}
