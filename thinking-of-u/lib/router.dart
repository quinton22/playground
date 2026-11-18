import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'blocs/auth/auth_bloc.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/phone_auth_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/store_screen.dart';

abstract class AppRoutes {
  static const splash = '/';
  static const phoneAuth = '/auth/phone';
  static const otp = '/auth/otp';
  static const profileSetup = '/auth/profile-setup';
  static const home = '/home';
  static const store = '/store';
  static const history = '/history';
  static const settings = '/settings';
}

/// A [ChangeNotifier] that listens to [AuthBloc] state changes and notifies
/// the GoRouter to re-evaluate its redirect logic.
class _AuthNotifier extends ChangeNotifier {
  final AuthBloc _authBloc;
  late final StreamSubscription<AuthState> _sub;
  AuthState _state;

  _AuthNotifier(this._authBloc) : _state = _authBloc.state {
    _sub = _authBloc.stream.listen((state) {
      _state = state;
      notifyListeners();
    });
  }

  AuthState get state => _state;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

class AppRouter {
  final AuthBloc _authBloc;
  late final _AuthNotifier _notifier;
  late final GoRouter _router;

  AppRouter(this._authBloc) {
    _notifier = _AuthNotifier(_authBloc);
    _router = GoRouter(
      initialLocation: AppRoutes.splash,
      refreshListenable: _notifier,
      redirect: (context, state) => _redirect(state),
      routes: [
        GoRoute(
          path: AppRoutes.splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: AppRoutes.phoneAuth,
          builder: (context, state) => const PhoneAuthScreen(),
        ),
        GoRoute(
          path: AppRoutes.otp,
          builder: (context, state) {
            final extra = state.extra as Map<String, String>?;
            return OtpScreen(
              phoneNumber: extra?['phone'] ?? '',
              verificationId: extra?['verificationId'] ?? '',
            );
          },
        ),
        GoRoute(
          path: AppRoutes.profileSetup,
          builder: (context, state) => const ProfileSetupScreen(),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.store,
          builder: (context, state) => const StoreScreen(),
        ),
        GoRoute(
          path: AppRoutes.history,
          builder: (context, state) => const HistoryScreen(),
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    );
  }

  GoRouter get router => _router;

  String? _redirect(GoRouterState state) {
    final authState = _notifier.state;
    final loc = state.matchedLocation;
    final isOnSplash = loc == AppRoutes.splash;
    final isOnAuth = loc.startsWith('/auth');

    if (authState is AuthInitial || authState is AuthLoading) {
      return isOnSplash ? null : AppRoutes.splash;
    }
    if (authState is AuthUnauthenticated || authState is AuthError) {
      return isOnAuth ? null : AppRoutes.phoneAuth;
    }
    // AuthCodeSent: let PhoneAuthScreen handle navigation to OTP imperatively
    // so it can pass the verificationId as route extra.
    if (authState is AuthCodeSent) {
      return null;
    }
    if (authState is AuthProfileSetupRequired) {
      return loc == AppRoutes.profileSetup ? null : AppRoutes.profileSetup;
    }
    if (authState is AuthAuthenticated) {
      return (isOnAuth || isOnSplash) ? AppRoutes.home : null;
    }
    return null;
  }

  void dispose() {
    _notifier.dispose();
    _router.dispose();
  }
}
