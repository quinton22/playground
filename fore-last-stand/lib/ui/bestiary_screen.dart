import 'package:material_ui/material_ui.dart';

import '../data/enemies.dart';
import '../meta/profile_store.dart';

/// Bestiary (spec 7): kills fill each entry.
class BestiaryScreen extends StatelessWidget {
  const BestiaryScreen({super.key, required this.store});

  final ProfileStore store;

  /// Kills to complete an entry.
  static const int entryGoal = 50;

  @override
  Widget build(BuildContext context) {
    final p = store.profile;
    final entries = bestiaryEntries;
    final done = entries.where((e) => (p.bestiary[e.id] ?? 0) >= entryGoal).length;
    return Scaffold(
      appBar: AppBar(title: Text('Bestiary  ·  $done/${entries.length} complete')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final e in entries)
            Card(
              child: ListTile(
                leading: CircleAvatar(backgroundColor: Color(e.colorValue)),
                title: Text((p.bestiary[e.id] ?? 0) > 0 ? e.name : '???'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((p.bestiary[e.id] ?? 0) > 0) Text('${e.behavior}\nCounter: ${e.counter}'),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: ((p.bestiary[e.id] ?? 0) / entryGoal).clamp(0.0, 1.0)),
                  ],
                ),
                trailing: Text('${p.bestiary[e.id] ?? 0}/$entryGoal'),
              ),
            ),
        ],
      ),
    );
  }
}
