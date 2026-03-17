import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for Firebase Phone Authentication.
class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  /// The current authenticated user, or null if not logged in.
  User? get currentUser => _auth.currentUser;

  /// Stream of authentication state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Whether the user is currently signed in.
  bool get isSignedIn => currentUser != null;

  /// Send an SMS verification code to the given phone number.
  ///
  /// [phoneNumber] must be in E.164 format (e.g., "+12025551234").
  ///
  /// Returns via callbacks:
  /// - [onCodeSent]: called with the verificationId when the SMS is sent.
  /// - [onVerificationCompleted]: called on Android with auto-retrieved credential.
  /// - [onError]: called if verification fails.
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(PhoneAuthCredential credential)
        onVerificationCompleted,
    required void Function(String error) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: onVerificationCompleted,
      verificationFailed: (FirebaseAuthException e) {
        debugPrint('Phone verification failed: ${e.code} - ${e.message}');
        onError(_authErrorMessage(e.code));
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        debugPrint('OTP auto-retrieval timeout: $verificationId');
      },
    );
  }

  /// Verify the OTP entered by the user and sign in.
  ///
  /// Returns the [UserCredential] on success, or throws on failure.
  Future<UserCredential> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  /// Sign in with a [PhoneAuthCredential] (used for auto-verified OTP on Android).
  Future<UserCredential> signInWithCredential(
      PhoneAuthCredential credential) async {
    return await _auth.signInWithCredential(credential);
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'The phone number is not valid. Please check and try again.';
      case 'too-many-requests':
        return 'Too many requests. Please wait a moment and try again.';
      case 'invalid-verification-code':
        return 'The verification code is incorrect. Please try again.';
      case 'session-expired':
        return 'The verification code has expired. Please request a new one.';
      default:
        return 'Verification failed. Please try again.';
    }
  }
}
