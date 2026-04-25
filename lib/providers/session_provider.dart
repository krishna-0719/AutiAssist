import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/local_db_service.dart';
import '../utils/app_logger.dart';

/// User role on this device.
enum UserRole { caregiver, child }

/// Centralized session state — single source of truth.
class SessionState {
  final UserRole? role;
  final String? familyCode;
  final String? familyId;
  final bool isReady;

  const SessionState({this.role, this.familyCode, this.familyId, this.isReady = false});

  bool get isLoggedIn => role != null && familyId != null;
  bool get isCaregiver => role == UserRole.caregiver;
  bool get isChild => role == UserRole.child;

  /// Copy with explicit null support.
  /// Pass [clearRole], [clearFamilyCode], [clearFamilyId] = true to set them to null.
  SessionState copyWith({
    UserRole? role,
    String? familyCode,
    String? familyId,
    bool? isReady,
    bool clearRole = false,
    bool clearFamilyCode = false,
    bool clearFamilyId = false,
  }) {
    return SessionState(
      role: clearRole ? null : (role ?? this.role),
      familyCode: clearFamilyCode ? null : (familyCode ?? this.familyCode),
      familyId: clearFamilyId ? null : (familyId ?? this.familyId),
      isReady: isReady ?? this.isReady,
    );
  }
}

/// Manages session state with Hive persistence AND Supabase auth validation.
class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier() : super(const SessionState()) {
    _loadFromLocal();
  }

  /// Restore session from Hive, but VALIDATE the Supabase token first.
  Future<void> _loadFromLocal() async {
    final savedRole = LocalDbService.savedRole;
    final savedCode = LocalDbService.savedFamilyCode;
    final savedId = LocalDbService.savedFamilyId;

    if (savedRole != null && savedId != null) {
      // Validate that the Supabase auth session is still alive
      final supabaseUser = Supabase.instance.client.auth.currentUser;
      final session = Supabase.instance.client.auth.currentSession;

      if (supabaseUser == null || session == null) {
        // Token expired or user signed out externally — clear stale session
        AppLogger.warning('Supabase token expired, clearing local session', tag: 'AUTH');
        await LocalDbService.clearSession();
        state = const SessionState(isReady: true);
        return;
      }

      // Check if token is about to expire (within 5 minutes)
      final expiresAt = session.expiresAt;
      if (expiresAt != null) {
        final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
        if (expiryTime.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
          // Try to refresh the session
          try {
            await Supabase.instance.client.auth.refreshSession();
            AppLogger.auth('Session token refreshed');
          } catch (e) {
            AppLogger.warning('Token refresh failed, clearing session', tag: 'AUTH');
            await LocalDbService.clearSession();
            state = const SessionState(isReady: true);
            return;
          }
        }
      }

      state = SessionState(
        role: savedRole == 'caregiver' ? UserRole.caregiver : UserRole.child,
        familyCode: savedCode,
        familyId: savedId,
        isReady: true,
      );
      AppLogger.auth('Session restored: $savedRole, family=$savedId');
    } else {
      state = state.copyWith(isReady: true);
    }
  }

  /// Set the session after login.
  Future<void> setSession({
    required UserRole role,
    required String familyCode,
    required String familyId,
  }) async {
    state = SessionState(
      role: role,
      familyCode: familyCode,
      familyId: familyId,
      isReady: true,
    );
    await LocalDbService.saveSession(
      role: role == UserRole.caregiver ? 'caregiver' : 'child',
      familyCode: familyCode,
      familyId: familyId,
    );
    AppLogger.auth('Session set: ${role.name}, family=$familyId');
  }

  /// Clear the session (logout) — including Supabase auth sign-out.
  Future<void> clearSession() async {
    // Sign out from Supabase first to invalidate the token
    try {
      await Supabase.instance.client.auth.signOut();
      AppLogger.auth('Supabase auth signed out');
    } catch (e) {
      AppLogger.warning('Supabase sign-out failed: $e', tag: 'AUTH');
    }

    // Then clear local session
    state = const SessionState(isReady: true);
    await LocalDbService.clearSession();
    AppLogger.auth('Session cleared');
  }
}

// ─── Providers ───────────────────────────────────────────────

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier();
});

/// Convenience: current role.
final currentRoleProvider = Provider<UserRole?>((ref) {
  return ref.watch(sessionProvider).role;
});

/// Convenience: family ID.
final familyIdProvider = Provider<String?>((ref) {
  return ref.watch(sessionProvider).familyId;
});

/// Convenience: is user logged in.
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(sessionProvider).isLoggedIn;
});
