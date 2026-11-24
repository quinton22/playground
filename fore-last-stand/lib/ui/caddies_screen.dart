import 'package:material_ui/material_ui.dart';

import '../data/caddies.dart';
import '../meta/profile_store.dart';
import '../meta/progression.dart';

class CaddiesScreen extends StatelessWidget {
  const CaddiesScreen({super.key, required this.store});

  final ProfileStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.profile;
        return Scaffold(
          appBar: AppBar(title: Text('Caddies  ·  🪙 ${p.coins}')),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final c in caddies)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          CircleAvatar(backgroundColor: Color(c.colorValue), child: Text(c.name[0])),
                          const SizedBox(width: 12),
                          Expanded(child: Text(c.name, style: Theme.of(context).textTheme.titleMedium)),
                        ]),
                        const SizedBox(height: 6),
                        Text('Passive: ${c.passiveText}'),
                        Text('Active, ${c.activeName} (${c.cooldown.round()} s): ${c.activeText}'),
                        const SizedBox(height: 8),
                        if (!p.caddiesUnlocked.contains(c.id))
                          FilledButton(
                            onPressed: c.unlockCoins > 0 && p.coins >= c.unlockCoins ? () => store.update((p) => unlockCaddie(p, c.id)) : null,
                            child: Text(c.unlockCoins == 0 ? 'Finish your first round' : 'Hire 🪙 ${c.unlockCoins}'),
                          )
                        else
                          OutlinedButton(
                            onPressed: () => store.update((p) => p.equippedCaddie = p.equippedCaddie == c.id ? null : c.id),
                            child: Text(p.equippedCaddie == c.id ? 'Equipped ✓' : 'Equip'),
                          ),
                      ],
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
