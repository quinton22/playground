import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/fore_game.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ForeApp());
}

class ForeApp extends StatelessWidget {
  const ForeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fore! Last Stand',
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: GameWidget(game: ForeGame())),
    );
  }
}
