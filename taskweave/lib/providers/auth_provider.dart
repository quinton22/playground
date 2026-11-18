import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _currentUser;
  String? _error;
  bool _isLoading = false;

  AuthProvider({required AuthService authService})
      : _authService = authService {
    _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  AuthStatus get status => _status;
  AppUser? get currentUser => _currentUser;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  void _onAuthStateChanged(User? user) async {
    if (user == null) {
      _status = AuthStatus.unauthenticated;
      _currentUser = null;
    } else {
      _status = AuthStatus.authenticated;
      _currentUser = await _authService.getCurrentAppUser();
    }
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _error = null;
    try {
      final user =
          await _authService.signInWithEmailAndPassword(email, password);
      _currentUser = user;
      _setLoading(false);
      return user != null;
    } on FirebaseAuthException catch (e) {
      _error = _mapFirebaseError(e.code);
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred.';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signUp(
      String email, String password, String displayName) async {
    _setLoading(true);
    _error = null;
    try {
      final user = await _authService.createUserWithEmailAndPassword(
          email, password, displayName);
      _currentUser = user;
      _setLoading(false);
      return user != null;
    } on FirebaseAuthException catch (e) {
      _error = _mapFirebaseError(e.code);
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred.';
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> sendPasswordReset(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } catch (e) {
      _error = 'Failed to send password reset email.';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
