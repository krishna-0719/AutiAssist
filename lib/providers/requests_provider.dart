import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/request_model.dart';
import 'service_providers.dart';
import 'session_provider.dart';

/// Fetches requests for the current family.
final requestsProvider =
    FutureProvider.autoDispose<List<RequestModel>>((ref) async {
  final familyId = ref.watch(familyIdProvider);
  if (familyId == null) return [];

  final requestRepo = ref.read(requestRepositoryProvider);
  return requestRepo.fetchRequests(familyId: familyId);
});
