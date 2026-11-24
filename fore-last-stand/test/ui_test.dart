import 'package:flutter_test/flutter_test.dart';
import 'package:fore_last_stand/main.dart';
import 'package:fore_last_stand/meta/profile.dart';
import 'package:fore_last_stand/meta/profile_store.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('home screen lists the modes and gates meta screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    await tester.pumpWidget(ForeApp(store: ProfileStore(Profile())));
    expect(find.text('Quick Round'), findsOneWidget);
    expect(find.text('Sudden Death'), findsOneWidget);
    expect(find.text('after 3 rounds'), findsOneWidget);
    expect(find.text('New here? Start with a Quick Round.'), findsOneWidget);
  });

  testWidgets('settings toggles persist into the profile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    final store = ProfileStore(Profile());
    await tester.pumpWidget(ForeApp(store: store));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Left-handed layout'));
    await tester.tap(find.text('Squeaky Clean (confetti)'));
    await tester.pumpAndSettle();
    expect(store.profile.settings.leftHanded, isTrue);
    expect(store.profile.settings.gore, GoreLevel.squeakyClean);
  });

  testWidgets('a run screen renders the HUD', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(ForeApp(store: ProfileStore(Profile())));
    await tester.tap(find.text('Quick Round'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Hole 1/5'), findsOneWidget);
    expect(find.text('FORE!'), findsOneWidget);
    expect(find.text('Driver'), findsOneWidget);
  });
}
