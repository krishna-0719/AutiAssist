import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';

/// ML Behavior Service — logs taps, retrieves contextual predictions,
/// triggers training, and syncs offline queues.
///
/// Uses the `http` package for direct REST calls to the Python backend.
/// Falls back to Supabase DB when backend is unreachable.
class BehaviorService {
  final SupabaseClient _client;
  String? _apiUrl;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  BehaviorService(this._client) {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        unawaited(syncOfflineLogs());
      }
    });
  }

  // ─── Headers ─────────────────────────────────────────────
  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        // API key can be injected via dart-define
        if (const String.fromEnvironment('BEHAVIOR_API_KEY').isNotEmpty)
          'X-API-Key': const String.fromEnvironment('BEHAVIOR_API_KEY'),
      };

  // ─── Auto-discover backend URL ───────────────────────────
  Future<String?> _getApiUrl() async {
    if (_apiUrl != null) return _apiUrl;

    // Try dart-define first
    const envUrl = String.fromEnvironment('BEHAVIOR_API_URL');
    if (envUrl.isNotEmpty) {
      _apiUrl = envUrl;
      return _apiUrl;
    }

    // Fall back to system_config table
    try {
      final result = await _client
          .from('system_config')
          .select('value')
          .eq('key', 'behavior_api_url')
          .maybeSingle();

      if (result != null && result['value'] != null) {
        _apiUrl = result['value'] as String;
      }
    } catch (e) {
      AppLogger.warning('Could not discover behavior API URL', tag: 'AI');
    }
    return _apiUrl;
  }

  // ─── Log a Tap ─────────────────────────────────────────────
  /// Log a symbol tap with full context for pattern learning.
  Future<void> logTap({
    required String familyId,
    required String userId,
    required String symbolType,
    required String room,
  }) async {
    final now = DateTime.now();
    final logData = {
      'family_id': familyId,
      'user_id': userId,
      'symbol_type': symbolType,
      'room': room,
      'hour_of_day': now.hour,
      'day_of_week': now.weekday % 7,
    };

    // Check connectivity
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      _queueOfflineLog(logData);
      return;
    }

    // Try backend REST API
    final url = await _getApiUrl();
    if (url != null) {
      try {
        final response = await http.post(
          Uri.parse('$url/log'),
          headers: _headers(),
          body: jsonEncode(logData),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          AppLogger.ai('Tap logged: $symbolType in $room at ${now.hour}:00');
          return;
        }
      } catch (e) {
        AppLogger.warning('Backend log failed, falling back to DB', tag: 'AI');
      }
    }

    // Fallback: insert directly into Supabase behavior_logs
    try {
      await _client.from('behavior_logs').insert(logData);
      AppLogger.ai('Tap logged to DB: $symbolType');
    } catch (_) {
      _queueOfflineLog(logData);
    }
  }

  // ─── Get Predictions ──────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPredictions({
    required String familyId,
    required String room,
    int? hour,
    int? dayOfWeek,
  }) async {
    final now = DateTime.now();
    final useHour = hour ?? now.hour;
    final useDay = dayOfWeek ?? (now.weekday % 7);

    // Try cache first (uses correct box name)
    final cached = _getCachedPredictions(familyId, room, useHour);
    if (cached != null) return cached;

    // Try backend REST API
    final url = await _getApiUrl();
    if (url != null) {
      try {
        final response = await http.get(
          Uri.parse('$url/predict/$familyId/$room?hour=$useHour&day=$useDay'),
          headers: _headers(),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final preds = List<Map<String, dynamic>>.from(
            (body['predictions'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
          );
          _cachePredictions(familyId, room, useHour, preds);
          return preds;
        }
      } catch (e) {
        AppLogger.warning('Backend predict failed, trying DB', tag: 'AI');
      }
    }

    // Fallback: read from Supabase behavior_predictions table
    try {
      final result = await _client
          .from('behavior_predictions')
          .select('predicted_types, confidence, model_version')
          .eq('family_id', familyId)
          .eq('room', room)
          .eq('hour_bucket', useHour)
          .maybeSingle();

      if (result != null && result['predicted_types'] != null) {
        final preds = List<Map<String, dynamic>>.from(
          (result['predicted_types'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        _cachePredictions(familyId, room, useHour, preds);
        return preds;
      }
    } catch (e) {
      AppLogger.warning('DB prediction fetch failed', tag: 'AI');
    }
    return [];
  }

  // ─── Trigger Training ──────────────────────────────────────
  Future<Map<String, dynamic>?> triggerTraining(String familyId) async {
    final url = await _getApiUrl();
    if (url == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$url/train/$familyId'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        AppLogger.ai('Training completed for family $familyId');
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      AppLogger.error('Training trigger failed', error: e, tag: 'AI');
    }
    return null;
  }

  // ─── Offline Queue (uses correct Hive box 'appData') ───────
  void _queueOfflineLog(Map<String, dynamic> logData) {
    try {
      // Use 'appData' to match LocalDbService — NOT 'app_data'
      final box = Hive.box('appData');
      final queue = List<Map<String, dynamic>>.from(
        (box.get('offline_behavior_queue', defaultValue: <dynamic>[]) as List)
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );
      queue.add(logData);
      box.put('offline_behavior_queue', queue);
      AppLogger.ai('Tap queued offline (${queue.length} pending)');
    } catch (e) {
      AppLogger.error('Failed to queue offline log', error: e, tag: 'AI');
    }
  }

  /// Sync queued offline logs when connectivity is restored.
  Future<void> syncOfflineLogs() async {
    try {
      final box = Hive.box('appData');
      final queue = List<Map<String, dynamic>>.from(
        (box.get('offline_behavior_queue', defaultValue: <dynamic>[]) as List)
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );

      if (queue.isEmpty) return;

      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) return;

      AppLogger.ai('Syncing ${queue.length} offline behavior logs');

      final remaining = <Map<String, dynamic>>[];
      for (final logData in queue) {
        try {
          await _client.from('behavior_logs').insert(logData);
        } catch (_) {
          remaining.add(logData);
        }
      }

      box.put('offline_behavior_queue', remaining);
      if (remaining.isEmpty) {
        AppLogger.ai('All offline logs synced');
      } else {
        AppLogger.warning('${remaining.length} logs still pending sync', tag: 'AI');
      }
    } catch (e) {
      AppLogger.error('Offline sync failed', error: e, tag: 'AI');
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  // ─── Prediction Cache ──────────────────────────────────────
  void _cachePredictions(String familyId, String room, int hour,
      List<Map<String, dynamic>> preds) {
    try {
      final box = Hive.box('appData');
      final key = 'pred_${familyId}_${room}_$hour';
      box.put(key, jsonEncode({
        'preds': preds,
        'cached_at': DateTime.now().toIso8601String(),
      }));
    } catch (_) {}
  }

  List<Map<String, dynamic>>? _getCachedPredictions(
      String familyId, String room, int hour) {
    try {
      final box = Hive.box('appData');
      final key = 'pred_${familyId}_${room}_$hour';
      final raw = box.get(key) as String?;
      if (raw == null) return null;

      final cached = jsonDecode(raw) as Map<String, dynamic>;
      final cachedAt = DateTime.parse(cached['cached_at'] as String);
      if (DateTime.now().difference(cachedAt).inMinutes > 30) return null;

      return List<Map<String, dynamic>>.from(
        (cached['preds'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
    } catch (_) {
      return null;
    }
  }
}
