import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/user_service.dart';
import '../../utils/crypto_utils.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthPhoneSubmitted extends AuthEvent {
  final String phoneNumber;
  const AuthPhoneSubmitted(this.phoneNumber);
  @override
  List<Object?> get props => [phoneNumber];
}

class AuthOtpSubmitted extends AuthEvent {
  final String verificationId;
  final String smsCode;
  const AuthOtpSubmitted(
      {required this.verificationId, required this.smsCode});
  @override
  List<Object?> get props => [verificationId, smsCode];
}

class AuthAutoVerified extends AuthEvent {
  final PhoneAuthCredential credential;
  const AuthAutoVerified(this.credential);
  @override
  List<Object?> get props => [credential];
}

class AuthProfileSetupSubmitted extends AuthEvent {
  final String displayName;
  const AuthProfileSetupSubmitted(this.displayName);
  @override
  List<Object?> get props => [displayName];
}

class AuthSignOutRequested extends AuthEvent {}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthCodeSent extends AuthState {
  final String phoneNumber;
  final String verificationId;
  const AuthCodeSent({required this.phoneNumber, required this.verificationId});
  @override
  List<Object?> get props => [phoneNumber, verificationId];
}

class AuthProfileSetupRequired extends AuthState {
  final String phoneNumber;
  final String phoneHash;
  const AuthProfileSetupRequired(
      {required this.phoneNumber, required this.phoneHash});
  @override
  List<Object?> get props => [phoneNumber, phoneHash];
}

class AuthAuthenticated extends AuthState {
  final UserModel user;
  const AuthAuthenticated(this.user);
  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  final UserService _userService;
  final NotificationService _notificationService;

  String? _pendingPhone;
  String? _pendingPhoneHash;

  AuthBloc({
    required AuthService authService,
    required UserService userService,
    required NotificationService notificationService,
  })  : _authService = authService,
        _userService = userService,
        _notificationService = notificationService,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthPhoneSubmitted>(_onPhoneSubmitted);
    on<AuthOtpSubmitted>(_onOtpSubmitted);
    on<AuthAutoVerified>(_onAutoVerified);
    on<AuthProfileSetupSubmitted>(_onProfileSetupSubmitted);
    on<AuthSignOutRequested>(_onSignOutRequested);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final user = _authService.currentUser;
    if (user == null) {
      emit(AuthUnauthenticated());
      return;
    }

    // Check if user profile exists
    final phoneHash = CryptoUtils.hashPhoneNumber(user.phoneNumber ?? '');
    final userModel = await _userService.getUserByHash(phoneHash);
    if (userModel == null) {
      emit(AuthProfileSetupRequired(
        phoneNumber: user.phoneNumber ?? '',
        phoneHash: phoneHash,
      ));
    } else {
      emit(AuthAuthenticated(userModel));
    }
  }

  Future<void> _onPhoneSubmitted(
    AuthPhoneSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    _pendingPhone = event.phoneNumber;
    _pendingPhoneHash = CryptoUtils.hashPhoneNumber(event.phoneNumber);

    PhoneAuthCredential? autoCredential;
    final stateCompleter = _PendingCompleter<AuthState>();

    await _authService.sendOtp(
      phoneNumber: event.phoneNumber,
      onCodeSent: (verificationId) {
        stateCompleter.complete(AuthCodeSent(
          phoneNumber: event.phoneNumber,
          verificationId: verificationId,
        ));
      },
      onVerificationCompleted: (credential) {
        autoCredential = credential;
        stateCompleter.complete(AuthLoading());
      },
      onError: (error) {
        stateCompleter.complete(AuthError(error));
      },
    );

    final result = await stateCompleter.future;
    if (autoCredential != null) {
      // Android auto-verified — sign in directly
      try {
        await _authService.signInWithCredential(autoCredential!);
        await _handleSignedIn(emit);
      } catch (e) {
        emit(const AuthError('Auto-verification failed. Please try again.'));
      }
    } else {
      emit(result);
    }
  }

  Future<void> _onOtpSubmitted(
    AuthOtpSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.verifyOtp(
        verificationId: event.verificationId,
        smsCode: event.smsCode,
      );
      await _handleSignedIn(emit);
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_authErrorMsg(e.code)));
    } catch (e) {
      emit(AuthError('Verification failed. Please try again.'));
    }
  }

  Future<void> _onAutoVerified(
    AuthAutoVerified event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.signInWithCredential(event.credential);
      await _handleSignedIn(emit);
    } catch (e) {
      emit(AuthError('Auto-verification failed. Please try again.'));
    }
  }

  Future<void> _onProfileSetupSubmitted(
    AuthProfileSetupSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final phone = _authService.currentUser?.phoneNumber ?? _pendingPhone ?? '';
      final phoneHash = _pendingPhoneHash ??
          CryptoUtils.hashPhoneNumber(phone);
      final fcmToken = await _notificationService.getToken();

      final userModel = await _userService.createOrUpdateUser(
        phoneHash: phoneHash,
        displayName: event.displayName.trim(),
        fcmToken: fcmToken,
      );

      emit(AuthAuthenticated(userModel));
    } catch (e) {
      emit(AuthError('Failed to save your profile. Please try again.'));
    }
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authService.signOut();
    emit(AuthUnauthenticated());
  }

  Future<void> _handleSignedIn(Emitter<AuthState> emit) async {
    final user = _authService.currentUser;
    if (user == null) {
      emit(AuthUnauthenticated());
      return;
    }

    final phone = user.phoneNumber ?? _pendingPhone ?? '';
    final phoneHash =
        _pendingPhoneHash ?? CryptoUtils.hashPhoneNumber(phone);
    final userModel = await _userService.getUserByHash(phoneHash);

    if (userModel == null) {
      emit(AuthProfileSetupRequired(
        phoneNumber: phone,
        phoneHash: phoneHash,
      ));
    } else {
      // Update FCM token
      final fcmToken = await _notificationService.getToken();
      if (fcmToken != null && fcmToken != userModel.fcmToken) {
        await _userService.updateFcmToken(phoneHash, fcmToken);
      }
      emit(AuthAuthenticated(userModel));
    }
  }

  String _authErrorMsg(String code) {
    switch (code) {
      case 'invalid-verification-code':
        return 'The code you entered is incorrect. Please try again.';
      case 'session-expired':
        return 'Your code has expired. Please request a new one.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}

/// Simple async completer helper.
class _PendingCompleter<T> {
  final _completer = Completer<T>();
  Future<T> get future => _completer.future;
  void complete(T value) {
    if (!_completer.isCompleted) _completer.complete(value);
  }
}
