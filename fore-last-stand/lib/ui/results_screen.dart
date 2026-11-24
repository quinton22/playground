import 'package:material_ui/material_ui.dart';

import '../data/caddies.dart';
import '../data/enemies.dart';
import '../data/modes.dart';
import '../meta/profile_store.dart';
import '../meta/progression.dart';
import '../sim/battle.dart';
import '../sim/combo.dart';
import 'run_screen.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, required this.store, required this.result, required this.rewards, required this.config});

  final ProfileStore store;
  final RunResult result;
  final Rewards rewards;
  final RunConfig config;

  @override
  Widget build(BuildContext context) {
    final near = nearestUnlocks(store.profile);
    final title = result.won ? 'The clubhouse stands!' : 'The animals took the clubhouse';
    return Scaffold(
      appBar: AppBar(title: Text(modeById(result.mode).name), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          _stat('Score', '${result.score}'),
          _stat('Holes cleared', '${result.holesCleared}'),
          _stat('Under par', '${result.underPar}'),
          _stat('Kills', '${result.kills}'),
          _stat('Best combo', ComboLadder.rungNames[result.bestRung]),
          _stat('Time', '${result.seconds.round()} s'),
          const Divider(),
          Text('Rewards', style: Theme.of(context).textTheme.titleMedium),
          _stat('Coins', '+${rewards.coins}'),
          _stat('Club Tokens', '+${rewards.tokens}'),
          _stat('XP', '+${rewards.xp}'),
          if (rewards.unlockedCaddie != null)
            Card(
              color: Colors.amber.shade100,
              child: ListTile(
                leading: const Icon(Icons.person_add),
                title: Text('New caddie: ${caddieById(rewards.unlockedCaddie!).name}'),
                subtitle: Text(caddieById(rewards.unlockedCaddie!).passiveText),
              ),
            ),
          if (result.killsById.isNotEmpty) ...[
            const Divider(),
            Text('Bestiary', style: Theme.of(context).textTheme.titleMedium),
            Wrap(
              spacing: 8,
              children: [
                for (final e in result.killsById.entries)
                  Chip(label: Text('${enemyById(e.key).name} ×${e.value}')),
              ],
            ),
          ],
          if (near.isNotEmpty) ...[
            const Divider(),
            Text('Almost there', style: Theme.of(context).textTheme.titleMedium),
            for (final u in near)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${u.name}  (${u.have}/${u.need} ${u.currency})'),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: u.progress, minHeight: 6),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => RunScreen(store: store, config: configFor(store.profile, result.mode)),
            )),
            child: const Text('One more hole'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to the clubhouse')),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]),
      );
}
