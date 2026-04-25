import 'package:supabase_flutter/supabase_flutter.dart';

import 'repositories/auth_repository.dart';
import 'repositories/family_repository.dart';
import 'repositories/request_repository.dart';
import 'repositories/room_repository.dart';
import 'repositories/symbol_repository.dart';
import 'repositories/entry_repository.dart';

/// Facade that provides access to all Supabase repositories.
///
/// Each repository handles its own domain; this class just
/// wires them together from a single SupabaseClient.
class SupabaseService {
  final SupabaseClient _client;

  late final AuthRepository auth;
  late final FamilyRepository families;
  late final RequestRepository requests;
  late final RoomRepository rooms;
  late final SymbolRepository symbols;
  late final EntryRepository entries;

  SupabaseService(this._client) {
    auth = AuthRepository(_client);
    families = FamilyRepository(_client);
    requests = RequestRepository(_client);
    rooms = RoomRepository(_client);
    symbols = SymbolRepository(_client);
    entries = EntryRepository(_client);
  }

  /// Convenience: current user ID.
  String? get userId => auth.userId;

  /// Convenience: Supabase client for direct access (e.g., Realtime).
  SupabaseClient get client => _client;
}
