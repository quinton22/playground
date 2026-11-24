import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'meta/profile_store.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final store = await ProfileStore.load();
  runApp(ForeApp(store: store));
}

class ForeApp extends StatelessWidget {
  const ForeApp({super.key, required this.store});

  final ProfileStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fore! Last Stand',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: HomeScreen(store: store),
    );
  }
}
