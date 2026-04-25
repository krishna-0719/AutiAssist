import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/environment_service.dart';
import '../services/child_location_service.dart';
import '../utils/app_logger.dart';
import 'service_providers.dart';
import 'session_provider.dart';

/// Room detection state for the child device.
class RoomDetectionState {
  final String currentRoom;
  final double confidence;
  final bool isScanning;
  final String? errorMessage;

  const RoomDetectionState({
    this.currentRoom = 'Detecting...',
    this.confidence = 0.0,
    this.isScanning = false,
    this.errorMessage,
  });

  RoomDetectionState copyWith({
    String? currentRoom,
    double? confidence,
    bool? isScanning,
    String? errorMessage,
  }) {
    return RoomDetectionState(
      currentRoom: currentRoom ?? this.currentRoom,
      confidence: confidence ?? this.confidence,
      isScanning: isScanning ?? this.isScanning,
      errorMessage: errorMessage,
    );
  }
}

class RoomDetectionNotifier extends StateNotifier<RoomDetectionState> {
  final EnvironmentService _envService;
  final ChildLocationService _locationService;
  final String? _familyId;
  Timer? _pollingTimer;
  String _previousRoom = '';

  RoomDetectionNotifier(this._envService, this._locationService, this._familyId)
      : super(const RoomDetectionState());

  void startScanning({Duration interval = const Duration(seconds: 8)}) {
    stopScanning();
    _doScan();
    _pollingTimer = Timer.periodic(interval, (_) => _doScan());

    final familyId = _familyId;
    if (familyId != null) {
      _locationService.joinFamilyChannel(familyId);
      _locationService.onFindChildPing(() {
        _locationService.broadcastRoom(
          room: state.currentRoom,
          confidence: state.confidence,
        );
      });
    }
  }

  void stopScanning() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _doScan() async {
    state = state.copyWith(isScanning: true);

    try {
      final result = await _envService.detectRoomWithConfidence();
      if (!mounted) return;

      if (result != null) {
        final room = result['room'] as String;
        final confidence = (result['confidence'] as double?) ?? 0.5;
        final roomChanged = room != _previousRoom;

        state = state.copyWith(
          currentRoom: room,
          confidence: confidence,
          isScanning: false,
          errorMessage: null,
        );

        if (roomChanged) {
          _previousRoom = room;
          AppLogger.room('Room changed → "$room" (${(confidence * 100).toInt()}%)');
          if (_familyId != null) {
            await _locationService.broadcastRoom(
              room: room,
              confidence: confidence,
            );
          }
        }
      } else {
        state = state.copyWith(
          currentRoom: 'Unknown',
          confidence: 0.0,
          isScanning: false,
        );
      }
    } catch (e) {
      if (mounted) {
        AppLogger.error('Room scan failed', error: e, tag: 'ROOM');
        state = state.copyWith(
          isScanning: false,
          errorMessage: 'Scan failed: $e',
        );
      }
    }
  }

  @override
  void dispose() {
    stopScanning();
    super.dispose();
  }
}

final roomDetectionProvider =
    StateNotifierProvider<RoomDetectionNotifier, RoomDetectionState>((ref) {
  final envService = ref.watch(environmentServiceProvider);
  final locationService = ref.watch(childLocationServiceProvider);
  final familyId = ref.watch(familyIdProvider);
  return RoomDetectionNotifier(envService, locationService, familyId);
});
