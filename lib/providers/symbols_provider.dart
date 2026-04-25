import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/repositories/symbol_repository.dart';
import 'service_providers.dart';
import 'session_provider.dart';

/// Fetches symbols from Supabase with offline cache fallback.
final symbolsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final familyId = ref.watch(familyIdProvider);
  if (familyId == null) return SymbolRepository.defaultSymbols;

  final symbolRepo = ref.read(symbolRepositoryProvider);
  return symbolRepo.getSymbols(familyId);
});
