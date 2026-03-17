import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/auth/auth_bloc.dart';
import 'router.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/purchase_service.dart';
import 'services/submission_service.dart';
import 'services/user_service.dart';
import 'theme/app_theme.dart';

class ThinkingOfUApp extends StatefulWidget {
  const ThinkingOfUApp({super.key});

  @override
  State<ThinkingOfUApp> createState() => _ThinkingOfUAppState();
}

class _ThinkingOfUAppState extends State<ThinkingOfUApp> {
  late final AuthService _authService;
  late final UserService _userService;
  late final SubmissionService _submissionService;
  late final NotificationService _notificationService;
  late final PurchaseService _purchaseService;
  late final AuthBloc _authBloc;
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _userService = UserService();
    _submissionService = SubmissionService();
    _notificationService = NotificationService();
    _purchaseService = PurchaseService(userService: _userService);
    _authBloc = AuthBloc(
      authService: _authService,
      userService: _userService,
      notificationService: _notificationService,
    )..add(AuthCheckRequested());
    _appRouter = AppRouter(_authBloc);

    _notificationService.initialize(
      onMessageReceived: (_) {},
      onMessageOpenedApp: (_) {},
    );
  }

  @override
  void dispose() {
    _authBloc.close();
    _appRouter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: _authService),
        RepositoryProvider.value(value: _userService),
        RepositoryProvider.value(value: _submissionService),
        RepositoryProvider.value(value: _notificationService),
        RepositoryProvider.value(value: _purchaseService),
      ],
      child: BlocProvider.value(
        value: _authBloc,
        child: MaterialApp.router(
          title: 'Thinking of U',
          theme: AppTheme.lightTheme,
          routerConfig: _appRouter.router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
