import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/room_model.dart';
import '../../utils/app_exceptions.dart';

/// Handles room CRUD operations in Supabase.
class RoomRepository {
  final SupabaseClient _client;

  RoomRepository(this._client);

  /// Fetch all rooms for a family.
  Future<List<RoomModel>> getRooms(String familyId) async {
    try {
      final response = await _client
          .from('rooms')
          .select()
          .eq('family_id', familyId)
          .order('created_at');
      return (response as List).map((e) => RoomModel.fromJson(e)).toList();
    } catch (e) {
      throw DataException('Failed to fetch rooms: $e', originalError: e);
    }
  }

  /// Add a new room.
  Future<RoomModel> addRoom({required String familyId, required String name}) async {
    try {
      final response = await _client
          .from('rooms')
          .insert({'family_id': familyId, 'name': name.trim()})
          .select()
          .single();
      return RoomModel.fromJson(response);
    } catch (e) {
      throw DataException('Failed to add room: $e', originalError: e);
    }
  }

  /// Delete a room.
  Future<void> deleteRoom(String roomId) async {
    try {
      await _client.from('rooms').delete().eq('id', roomId);
    } catch (e) {
      throw DataException('Failed to delete room: $e', originalError: e);
    }
  }
}
