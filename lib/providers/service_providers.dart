import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../services/behavior_service.dart';
import '../services/child_location_service.dart';
import '../services/environment_service.dart';
import '../services/repositories/auth_repository.dart';
import '../services/repositories/family_repository.dart';
import '../services/repositories/request_repository.dart';
import '../services/repositories/room_repository.dart';
import '../services/repositories/symbol_repository.dart';
import '../services/repositories/entry_repository.dart';

// ─── Core Supabase client ────────────────────────────────────
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ─── Facade ──────────────────────────────────────────────────
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService(ref.watch(supabaseClientProvider));
});

// ─── Individual Repositories ─────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return ref.watch(supabaseServiceProvider).auth;
});

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return ref.watch(supabaseServiceProvider).families;
});

final requestRepositoryProvider = Provider<RequestRepository>((ref) {
  return ref.watch(supabaseServiceProvider).requests;
});

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return ref.watch(supabaseServiceProvider).rooms;
});

final symbolRepositoryProvider = Provider<SymbolRepository>((ref) {
  return ref.watch(supabaseServiceProvider).symbols;
});

final entryRepositoryProvider = Provider<EntryRepository>((ref) {
  return ref.watch(supabaseServiceProvider).entries;
});

// ─── Other Services ──────────────────────────────────────────
final environmentServiceProvider = Provider<EnvironmentService>((ref) {
  return EnvironmentService();
});

final behaviorServiceProvider = Provider<BehaviorService>((ref) {
  final service = BehaviorService(ref.watch(supabaseClientProvider));
  ref.onDispose(service.dispose);
  return service;
});

final childLocationServiceProvider = Provider<ChildLocationService>((ref) {
  final service = ChildLocationService(ref.watch(supabaseClientProvider));
  ref.onDispose(service.dispose);
  return service;
});
