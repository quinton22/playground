import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart' as app_auth;
import 'providers/todo_provider.dart';
import 'providers/sms_provider.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'services/sms_service.dart';
import 'screens/splash_screen.dart';
import 'utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(TaskWeaveApp(notificationService: notificationService));
}

class TaskWeaveApp extends StatelessWidget {
  final NotificationService notificationService;

  const TaskWeaveApp({super.key, required this.notificationService});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final firestoreService = FirestoreService();
    final smsService = SmsService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => app_auth.AuthProvider(authService: authService),
        ),
        ChangeNotifierProvider(
          create: (_) => TodoProvider(
            firestoreService: firestoreService,
            authService: authService,
            notificationService: notificationService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SmsProvider(smsService: smsService),
        ),
      ],
      child: MaterialApp(
        title: 'TaskWeave',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const SplashScreen(),
      ),
    );
  }
}
