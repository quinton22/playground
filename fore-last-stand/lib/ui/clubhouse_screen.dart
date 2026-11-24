import 'package:material_ui/material_ui.dart';

import '../meta/profile_store.dart';
import '../meta/progression.dart';

/// Clubhouse upgrade tree (spec 7): grows the grid, adds starting coins and HP.
class ClubhouseScreen extends StatelessWidget {
  const ClubhouseScreen({super.key, required this.store});

  final ProfileStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.profile;
        final grid = 4 + p.clubhouseLevel('grid');
        return Scaffold(
          appBar: AppBar(title: Text('Clubhouse  ·  🪙 ${p.coins}')),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text('Grounds: ${grid}x$grid plots · Start with ${60 + 20 * p.clubhouseLevel('coins')} coins · '
                  '${100 + 20 * p.clubhouseLevel('walls')} HP'),
              const SizedBox(height: 8),
              for (final u in clubhouseUpgrades)
                Card(
                  child: ListTile(
                    title: Text('${u.name}  (${p.clubhouseLevel(u.id)}/${u.maxLevel})'),
                    subtitle: Text(u.description),
                    trailing: p.clubhouseLevel(u.id) >= u.maxLevel
                        ? const Text('Max')
                        : FilledButton(
                            onPressed: p.coins >= u.cost(p.clubhouseLevel(u.id)) ? () => store.update((p) => buyClubhouseUpgrade(p, u.id)) : null,
                            child: Text('🪙 ${u.cost(p.clubhouseLevel(u.id))}'),
                          ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
