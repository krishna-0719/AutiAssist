import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/child_location.dart';
import '../services/child_location_service.dart';
import 'service_providers.dart';
import 'session_provider.dart';

/// Find Child state for the caregiver.
class FindChildState {
  final ChildLocation? lastKnownLocation;
  final bool isTracking;
  final bool isPinging;
  final bool continuousMode;

  const FindChildState({
    this.lastKnownLocation,
    this.isTracking = false,
    this.isPinging = false,
    this.continuousMode = false,
  });

  FindChildState copyWith({
    ChildLocation? lastKnownLocation,
    bool? isTracking,
    bool? isPinging,
    bool? continuousMode,
  }) {
    return FindChildState(
      lastKnownLocation: lastKnownLocation ?? this.lastKnownLocation,
      isTracking: isTracking ?? this.isTracking,
      isPinging: isPinging ?? this.isPinging,
      continuousMode: continuousMode ?? this.continuousMode,
    );
  }
}

class FindChildNotifier extends StateNotifier<FindChildState> {
  final ChildLocationService _locationService;
  final String? _familyId;
  StreamSubscription<ChildLocation>? _subscription;

  FindChildNotifier(this._locationService, this._familyId)
      : super(const FindChildState());

  Future<void> findChildNow() async {
    final familyId = _familyId;
    if (familyId == null) return;

    _locationService.joinFamilyChannel(familyId);
    state = state.copyWith(isPinging: true);
    _ensureListening();
    await _locationService.requestChildLocation();

    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && state.isPinging) {
        state = state.copyWith(isPinging: false);
      }
    });
  }

  void toggleContinuousTracking(bool enabled) {
    final familyId = _familyId;
    if (familyId == null) return;

    if (enabled) {
      _locationService.joinFamilyChannel(familyId);
      _ensureListening();
      state = state.copyWith(continuousMode: true, isTracking: true);
    } else {
      _subscription?.cancel();
      _subscription = null;
      state = state.copyWith(continuousMode: false, isTracking: false);
    }
  }

  void _ensureListening() {
    if (_subscription != null) return;
    _subscription = _locationService.locationStream.listen((location) {
      state = state.copyWith(
        lastKnownLocation: location,
        isPinging: false,
      );
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final findChildProvider =
    StateNotifierProvider<FindChildNotifier, FindChildState>((ref) {
  final locationService = ref.watch(childLocationServiceProvider);
  final familyId = ref.watch(familyIdProvider);
  return FindChildNotifier(locationService, familyId);
});
