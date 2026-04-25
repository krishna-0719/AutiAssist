import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/entry_model.dart';
import '../../utils/app_exceptions.dart';

/// Handles caregiver diary entry CRUD.
class EntryRepository {
  final SupabaseClient _client;

  EntryRepository(this._client);

  /// Fetch all entries for a family.
  Future<List<EntryModel>> getEntries(String familyId) async {
    try {
      final response = await _client
          .from('entries')
          .select()
          .eq('family_id', familyId)
          .order('created_at', ascending: false);
      return (response as List).map((e) => EntryModel.fromJson(e)).toList();
    } catch (e) {
      throw DataException('Failed to fetch entries: $e', originalError: e);
    }
  }

  /// Add a new diary entry.
  Future<EntryModel> addEntry({
    required String familyId,
    required String title,
    String? description,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      final response = await _client
          .from('entries')
          .insert({
            'family_id': familyId,
            'user_id': userId,
            'title': title.trim(),
            'description': description?.trim(),
          })
          .select()
          .single();
      return EntryModel.fromJson(response);
    } catch (e) {
      throw DataException('Failed to add entry: $e', originalError: e);
    }
  }

  /// Delete a diary entry.
  Future<void> deleteEntry(String entryId) async {
    try {
      await _client.from('entries').delete().eq('id', entryId);
    } catch (e) {
      throw DataException('Failed to delete entry: $e', originalError: e);
    }
  }
}
