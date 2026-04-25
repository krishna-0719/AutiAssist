import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/child_location.dart';
import '../utils/app_logger.dart';

/// Manages real-time child location tracking via Supabase Broadcast.
///
/// Architecture: ZERO database writes, purely in-memory WebSocket broadcast.
/// Channel: `family_tracking:{familyId}`
/// Events:
///   - `child_room_update` — child broadcasts current room
///   - `find_child_ping` — caregiver requests location
class ChildLocationService {
  final SupabaseClient _client;

  RealtimeChannel? _channel;
  String? _activeFamilyId;
  final _locationController = StreamController<ChildLocation>.broadcast();
  void Function()? _onPingCallback;

  ChildLocationService(this._client);

  /// Stream of child location updates (for caregiver).
  Stream<ChildLocation> get locationStream => _locationController.stream;

  /// Join the family's tracking broadcast channel.
  void joinFamilyChannel(String familyId) {
    if (_activeFamilyId == familyId && _channel != null) return;

    _channel?.unsubscribe();
    _channel = null;
    _onPingCallback = null;
    _activeFamilyId = familyId;

    _channel = _client.channel('family_tracking:$familyId');

    _channel!
        .onBroadcast(event: 'child_room_update', callback: (payload) {
          final location = ChildLocation.fromBroadcast(payload);
          _locationController.add(location);
          AppLogger.track('Received room update: ${location.room} (${location.confidencePercent}%)');
        })
        .onBroadcast(event: 'find_child_ping', callback: (_) {
          AppLogger.track('Received find-child ping');
          _onPingCallback?.call();
        })
        .subscribe();

    AppLogger.track('Joined tracking channel: family_tracking:$familyId');
  }

  /// Broadcast current room (called by child device).
  Future<void> broadcastRoom({
    required String room,
    required double confidence,
  }) async {
    if (_channel == null) return;

    await _channel!.sendBroadcastMessage(
      event: 'child_room_update',
      payload: {
        'room': room,
        'confidence': confidence,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// Send a "find child" ping (called by caregiver).
  Future<void> requestChildLocation() async {
    if (_channel == null) return;

    await _channel!.sendBroadcastMessage(
      event: 'find_child_ping',
      payload: {'timestamp': DateTime.now().toUtc().toIso8601String()},
    );
    AppLogger.track('Sent find-child ping');
  }

  /// Register a callback for when the caregiver pings (child device).
  void onFindChildPing(void Function() callback) {
    _onPingCallback = callback;
  }

  /// Leave the channel and clean up.
  void dispose() {
    _channel?.unsubscribe();
    _channel = null;
    _activeFamilyId = null;
    _locationController.close();
  }
}
