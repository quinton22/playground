import 'package:material_ui/material_ui.dart';

import '../meta/profile.dart';
import '../meta/profile_store.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store});

  final ProfileStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store.profile.settings;
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            children: [
              ListTile(
                title: const Text('Aim assist'),
                subtitle: Slider(
                  value: s.aimAssist,
                  divisions: 10,
                  label: '${(s.aimAssist * 100).round()}%',
                  onChanged: (v) => store.update((p) => p.settings.aimAssist = v),
                ),
              ),
              SwitchListTile(
                title: const Text('Auto-Caddie'),
                subtitle: const Text('Swings for you at reduced damage.'),
                value: s.autoCaddie,
                onChanged: (v) => store.update((p) => p.settings.autoCaddie = v),
              ),
              SwitchListTile(
                title: const Text('Left-handed layout'),
                subtitle: const Text('Moves the round controls to the left.'),
                value: s.leftHanded,
                onChanged: (v) => store.update((p) => p.settings.leftHanded = v),
              ),
              SwitchListTile(
                title: const Text('Screen shake'),
                value: s.screenShake,
                onChanged: (v) => store.update((p) => p.settings.screenShake = v),
              ),
              const ListTile(title: Text('Gore')),
              RadioGroup<GoreLevel>(
                groupValue: s.gore,
                onChanged: (v) => store.update((p) => p.settings.gore = v ?? GoreLevel.classic),
                child: Column(
                  children: [
                    for (final g in GoreLevel.values)
                      RadioListTile<GoreLevel>(
                        title: Text(switch (g) {
                          GoreLevel.fullSplat => 'Full Splat',
                          GoreLevel.classic => 'Classic',
                          GoreLevel.squeakyClean => 'Squeaky Clean (confetti)',
                        }),
                        value: g,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
