import 'package:flutter_test/flutter_test.dart';

import 'package:care_child_app/providers/session_provider.dart';

void main() {
  group('SessionState', () {
    test('defaults to not ready and logged out', () {
      const state = SessionState();

      expect(state.isReady, isFalse);
      expect(state.isLoggedIn, isFalse);
      expect(state.isCaregiver, isFalse);
      expect(state.isChild, isFalse);
    });

    test('copyWith preserves existing values and updates selected fields', () {
      const state = SessionState(
        role: UserRole.child,
        familyCode: 'ABC123',
        familyId: 'family-1',
        isReady: true,
      );

      final updated = state.copyWith(familyCode: 'XYZ789');

      expect(updated.role, UserRole.child);
      expect(updated.familyCode, 'XYZ789');
      expect(updated.familyId, 'family-1');
      expect(updated.isReady, isTrue);
      expect(updated.isLoggedIn, isTrue);
      expect(updated.isChild, isTrue);
    });

    test('caregiver session is marked logged in', () {
      const state = SessionState(
        role: UserRole.caregiver,
        familyCode: 'FAM001',
        familyId: 'family-2',
        isReady: true,
      );

      expect(state.isLoggedIn, isTrue);
      expect(state.isCaregiver, isTrue);
      expect(state.isChild, isFalse);
    });
  });
}