import 'package:material_ui/material_ui.dart';

import '../data/clubs.dart';
import '../meta/profile_store.dart';
import '../meta/progression.dart';

/// The Bag (spec 7): unlock, level and equip clubs with Club Tokens.
class BagScreen extends StatelessWidget {
  const BagScreen({super.key, required this.store});

  final ProfileStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.profile;
        return Scaffold(
          appBar: AppBar(title: Text('The Bag  ·  🎟 ${p.clubTokens}')),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const Text('Equip up to 3 clubs. Swap between them with a tap during a round.'),
              const SizedBox(height: 8),
              for (final c in clubs) _clubCard(context, c),
            ],
          ),
        );
      },
    );
  }

  Widget _clubCard(BuildContext context, ClubSpec c) {
    final p = store.profile;
    final unlocked = p.unlockedClubs.contains(c.id);
    final level = p.clubLevel(c.id);
    final inBag = p.bag.contains(c.id);
    final cost = clubUpgradeCost(level);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(c.name, style: Theme.of(context).textTheme.titleMedium)),
              if (unlocked) Text('Level $level/$maxClubLevel'),
            ]),
            Text('Best against: ${c.bestAgainst}'),
            Text('Damage ${(c.damage * (1 + 0.05 * (level - 1))).toStringAsFixed(1)} · pierce ${c.pierce} · bounces ${c.bounces}'
                '${c.blastRadius > 0 ? ' · blast ${c.blastRadius.round()}' : ''}'),
            if (unlocked) Text(clubTrait(level), style: const TextStyle(fontStyle: FontStyle.italic)),
            const SizedBox(height: 8),
            if (!unlocked)
              FilledButton(
                onPressed: p.clubTokens >= c.unlockTokens ? () => store.update((p) => unlockClub(p, c.id)) : null,
                child: Text('Unlock 🎟 ${c.unlockTokens}'),
              )
            else
              Row(children: [
                Expanded(
                  child: FilledButton(
                    onPressed: level < maxClubLevel && p.clubTokens >= cost ? () => store.update((p) => upgradeClub(p, c.id)) : null,
                    child: Text(level < maxClubLevel ? 'Level up 🎟 $cost' : 'Maxed'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => store.update((p) => toggleBag(p, c.id)),
                    child: Text(inBag ? 'In bag ✓' : 'Add to bag'),
                  ),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}
