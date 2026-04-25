import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../utils/app_exceptions.dart';
import '../../utils/app_logger.dart';

/// Handles authentication operations via Supabase Auth.
class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  /// Get the current authenticated user ID.
  String? get userId => _client.auth.currentUser?.id;

  /// Whether a user is currently signed in.
  bool get isSignedIn => _client.auth.currentUser != null;

  /// Sign up a caregiver with email and password.
  Future<String> signUpWithEmail(String email, String password) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      if (response.user == null) {
        throw const AuthException('Sign up failed — no user returned.');
      }
      AppLogger.auth('Caregiver signed up: ${response.user!.id}');
      return response.user!.id;
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Sign up failed: $e', originalError: e);
    }
  }

  /// Sign in a caregiver with email and password.
  Future<String> signInWithPassword(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user == null) {
        throw const AuthException('Sign in failed — invalid credentials.');
      }
      AppLogger.auth('Caregiver signed in: ${response.user!.id}');
      return response.user!.id;
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Sign in failed: $e', originalError: e);
    }
  }

  /// Sign in anonymously for a child device.
  Future<String> signInAnonymously() async {
    try {
      final response = await _client.auth.signInAnonymously();
      if (response.user == null) {
        throw const AuthException('Anonymous sign in failed.');
      }
      AppLogger.auth('Child signed in anonymously: ${response.user!.id}');
      return response.user!.id;
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Anonymous sign in failed: $e', originalError: e);
    }
  }

  /// Send a password reset email for a caregiver account.
  Future<void> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
      AppLogger.auth('Password reset requested for: $email');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Password reset failed: $e', originalError: e);
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      AppLogger.auth('User signed out');
    } catch (e) {
      throw AuthException('Sign out failed: $e', originalError: e);
    }
  }
}
