import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_logger.dart';
import 'service_providers.dart';
import 'session_provider.dart';

/// Analytics data state.
class AnalyticsState {
  final List<Map<String, dynamic>> dailyData;
  final Map<String, int> typeData;
  final Map<String, int> roomData;
  final Map<int, int> hourData;
  final bool isLoading;
  final String? errorMessage;

  const AnalyticsState({
    this.dailyData = const [],
    this.typeData = const {},
    this.roomData = const {},
    this.hourData = const {},
    this.isLoading = true,
    this.errorMessage,
  });

  AnalyticsState copyWith({
    List<Map<String, dynamic>>? dailyData,
    Map<String, int>? typeData,
    Map<String, int>? roomData,
    Map<int, int>? hourData,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AnalyticsState(
      dailyData: dailyData ?? this.dailyData,
      typeData: typeData ?? this.typeData,
      roomData: roomData ?? this.roomData,
      hourData: hourData ?? this.hourData,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AnalyticsNotifier extends StateNotifier<AnalyticsState> {
  final Ref _ref;
  final String? _familyId;

  AnalyticsNotifier(this._ref, this._familyId)
      : super(const AnalyticsState()) {
    loadData();
  }

  Future<void> loadData() async {
    if (_familyId == null) return;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final repo = _ref.read(requestRepositoryProvider);
      final results = await Future.wait([
        repo.getRequestsByDay(familyId: _familyId!),
        repo.getRequestsByType(familyId: _familyId!),
        repo.getRequestsByRoom(familyId: _familyId!),
        repo.getPeakHours(familyId: _familyId!),
      ]);

      if (mounted) {
        state = state.copyWith(
          dailyData: results[0] as List<Map<String, dynamic>>,
          typeData: results[1] as Map<String, int>,
          roomData: results[2] as Map<String, int>,
          hourData: results[3] as Map<int, int>,
          isLoading: false,
        );
      }
    } catch (e) {
      AppLogger.error('Analytics load failed', error: e);
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load analytics.',
        );
      }
    }
  }
}

final analyticsProvider =
    StateNotifierProvider<AnalyticsNotifier, AnalyticsState>((ref) {
  final familyId = ref.watch(familyIdProvider);
  return AnalyticsNotifier(ref, familyId);
});
