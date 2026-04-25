import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/family_model.dart';
import '../../utils/app_exceptions.dart';
import '../../utils/app_logger.dart';

/// Handles family CRUD and family code operations.
class FamilyRepository {
  final SupabaseClient _client;

  FamilyRepository(this._client);

  /// Create a new family with a unique code.
  Future<FamilyModel> createFamily(String familyCode, {String? pinHash}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      final data = {
        'family_code': familyCode.toUpperCase().trim(),
        'created_by': userId,
        if (pinHash != null) 'pin_hash': pinHash,
      };
      final response = await _client
          .from('families')
          .insert(data)
          .select()
          .single();
      AppLogger.info('Family created: ${response['id']}', tag: 'FAMILY');
      return FamilyModel.fromJson(response);
    } catch (e) {
      throw DataException('Failed to create family: $e', originalError: e);
    }
  }

  /// Look up a family by its code.
  /// Normalizes to uppercase to match createFamily() and the RPC.
  Future<FamilyModel?> findByCode(String code) async {
    try {
      final normalizedCode = code.trim().toUpperCase();
      final response = await _client
          .from('families')
          .select()
          .eq('family_code', normalizedCode)
          .maybeSingle();
      if (response == null) return null;
      return FamilyModel.fromJson(response);
    } catch (e) {
      throw DataException('Failed to look up family: $e', originalError: e);
    }
  }

  /// Get a family by its ID.
  Future<FamilyModel?> getById(String familyId) async {
    try {
      final response = await _client
          .from('families')
          .select()
          .eq('id', familyId)
          .maybeSingle();
      if (response == null) return null;
      return FamilyModel.fromJson(response);
    } catch (e) {
      throw DataException('Failed to get family: $e', originalError: e);
    }
  }

  /// Find the family created by the current user.
  Future<FamilyModel?> findMyFamily() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;
      final response = await _client
          .from('families')
          .select()
          .eq('created_by', userId)
          .maybeSingle();
      if (response == null) return null;
      return FamilyModel.fromJson(response);
    } catch (e) {
      throw DataException('Failed to find user family: $e', originalError: e);
    }
  }

  /// Update the PIN hash for a family.
  Future<void> updatePin(String familyId, String pinHash) async {
    try {
      await _client
          .from('families')
          .update({'pin_hash': pinHash})
          .eq('id', familyId);
    } catch (e) {
      throw DataException('Failed to update PIN: $e', originalError: e);
    }
  }

  /// Verify a PIN against the stored hash.
  Future<bool> verifyPin(String familyId, String pinHash) async {
    try {
      final family = await getById(familyId);
      return family?.pinHash == pinHash;
    } catch (e) {
      return false;
    }
  }
}
