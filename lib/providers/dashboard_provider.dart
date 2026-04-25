import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/repositories/request_repository.dart';
import '../utils/app_logger.dart';
import 'service_providers.dart';
import 'session_provider.dart';

/// Dashboard state for the caregiver home screen.
class DashboardState {
  final int pendingCount;
  final int todayCount;
  final int totalCount;
  final int doneCount;
  final int entryCount;
  final String? familyCode;
  final bool isLoading;
  final String? errorMessage;

  const DashboardState({
    this.pendingCount = 0,
    this.todayCount = 0,
    this.totalCount = 0,
    this.doneCount = 0,
    this.entryCount = 0,
    this.familyCode,
    this.isLoading = true,
    this.errorMessage,
  });

  DashboardState copyWith({
    int? pendingCount,
    int? todayCount,
    int? totalCount,
    int? doneCount,
    int? entryCount,
    String? familyCode,
    bool? isLoading,
    String? errorMessage,
  }) {
    return DashboardState(
      pendingCount: pendingCount ?? this.pendingCount,
      todayCount: todayCount ?? this.todayCount,
      totalCount: totalCount ?? this.totalCount,
      doneCount: doneCount ?? this.doneCount,
      entryCount: entryCount ?? this.entryCount,
      familyCode: familyCode ?? this.familyCode,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final RequestRepository _requestRepo;
  final SessionState _session;

  DashboardNotifier(this._requestRepo, this._session)
      : super(const DashboardState()) {
    loadData();
  }

  Future<void> loadData() async {
    if (!_session.isLoggedIn) return;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final familyId = _session.familyId!;
      final stats = await _requestRepo.getStats(familyId: familyId);

      if (mounted) {
        state = state.copyWith(
          pendingCount: stats['pending'] ?? 0,
          todayCount: stats['today'] ?? 0,
          totalCount: stats['total'] ?? 0,
          doneCount: stats['done'] ?? 0,
          entryCount: stats['entries'] ?? 0,
          familyCode: _session.familyCode,
          isLoading: false,
        );
      }
    } catch (e) {
      AppLogger.error('Dashboard load failed', error: e);
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load dashboard data.',
        );
      }
    }
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  final requestRepo = ref.watch(requestRepositoryProvider);
  final session = ref.watch(sessionProvider);
  return DashboardNotifier(requestRepo, session);
});
