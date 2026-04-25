import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/request_model.dart';
import '../../services/local_db_service.dart';
import '../../utils/app_exceptions.dart';
import '../../utils/app_logger.dart';

/// Handles request CRUD, realtime streaming, analytics, and offline queueing.
class RequestRepository {
  final SupabaseClient _client;

  RequestRepository(this._client);

  /// Create a new request from the child. Falls back to offline queue.
  Future<void> createRequest({
    required String type,
    required String room,
    required String familyId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final data = {
      'type': type,
      'room': room,
      'family_id': familyId,
      'user_id': userId,
      'status': 'pending',
    };

    try {
      await _client.from('requests').insert(data);
      AppLogger.info('Request created: $type from $room', tag: 'REQ');
      // Sync any offline queue on success
      await _syncOfflineQueue();
    } catch (e) {
      AppLogger.warning('Request offline-queued: $type', tag: 'NET');
      await LocalDbService.queueOfflineRequest(data);
    }
  }

  /// Fetch requests for a family (last 24 hours).
  Future<List<RequestModel>> fetchRequests({required String familyId}) async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();
      final response = await _client
          .from('requests')
          .select()
          .eq('family_id', familyId)
          .gte('created_at', cutoff)
          .order('created_at', ascending: false);
      return (response as List).map((e) => RequestModel.fromJson(e)).toList();
    } catch (e) {
      throw DataException('Failed to fetch requests: $e', originalError: e);
    }
  }

  /// Realtime stream of requests for a family.
  Stream<List<Map<String, dynamic>>> streamRequests({required String familyId}) {
    return _client
        .from('requests')
        .stream(primaryKey: ['id'])
        .eq('family_id', familyId);
  }

  /// Update request status (e.g., pending → done).
  Future<void> updateStatus({required String requestId, required String status}) async {
    try {
      await _client
          .from('requests')
          .update({'status': status})
          .eq('id', requestId);
    } catch (e) {
      throw DataException('Failed to update request: $e', originalError: e);
    }
  }

  /// Delete a request.
  Future<void> deleteRequest(String requestId) async {
    try {
      await _client.from('requests').delete().eq('id', requestId);
    } catch (e) {
      throw DataException('Failed to delete request: $e', originalError: e);
    }
  }

  // ─── Analytics ─────────────────────────────────────────────

  /// Dashboard stats via RPC (with client-side fallback).
  Future<Map<String, int>> getStats({required String familyId}) async {
    try {
      final result = await _client.rpc('get_dashboard_stats', params: {'p_family_id': familyId});
      if (result is Map) {
        return {
          'total': (result['total_requests'] as num?)?.toInt() ?? 0,
          'done': (result['done_count'] as num?)?.toInt() ?? 0,
          'pending': (result['pending_count'] as num?)?.toInt() ?? 0,
          'today': (result['today_count'] as num?)?.toInt() ?? 0,
          'entries': (result['total_entries'] as num?)?.toInt() ?? 0,
        };
      }
    } catch (_) {
      AppLogger.warning('RPC get_dashboard_stats failed, using fallback', tag: 'RPC');
    }
    // Fallback: count client-side
    try {
      final all = await _client.from('requests').select('id, status').eq('family_id', familyId);
      final list = all as List;
      return {
        'total': list.length,
        'pending': list.where((r) => r['status'] == 'pending').length,
        'done': list.where((r) => r['status'] == 'done').length,
        'today': 0,
        'entries': 0,
      };
    } catch (e) {
      throw DataException('Failed to get stats: $e', originalError: e);
    }
  }

  /// Requests grouped by day (last 7 days).
  Future<List<Map<String, dynamic>>> getRequestsByDay({
    required String familyId,
    int days = 7,
  }) async {
    try {
      final result = await _client.rpc('get_requests_by_day', params: {'p_family_id': familyId});
      if (result is List) return List<Map<String, dynamic>>.from(result);
    } catch (_) {
      AppLogger.warning('RPC get_requests_by_day failed', tag: 'RPC');
    }
    return [];
  }

  /// Requests grouped by type.
  Future<Map<String, int>> getRequestsByType({required String familyId}) async {
    try {
      final result = await _client.rpc('get_requests_by_type', params: {'p_family_id': familyId});
      if (result is List) {
        return {for (var r in result) r['type'] as String: (r['count'] as num).toInt()};
      }
    } catch (_) {
      AppLogger.warning('RPC get_requests_by_type failed', tag: 'RPC');
    }
    return {};
  }

  /// Requests grouped by room.
  Future<Map<String, int>> getRequestsByRoom({required String familyId}) async {
    try {
      final result = await _client.rpc('get_requests_by_room', params: {'p_family_id': familyId});
      if (result is List) {
        return {for (var r in result) r['room'] as String: (r['count'] as num).toInt()};
      }
    } catch (_) {
      AppLogger.warning('RPC get_requests_by_room failed', tag: 'RPC');
    }
    return {};
  }

  /// Peak hours from behavior_logs.
  Future<Map<int, int>> getPeakHours({required String familyId}) async {
    try {
      final result = await _client.rpc('get_peak_hours', params: {'p_family_id': familyId});
      if (result is List) {
        return {for (var r in result) (r['hour'] as num).toInt(): (r['count'] as num).toInt()};
      }
    } catch (_) {
      AppLogger.warning('RPC get_peak_hours failed', tag: 'RPC');
    }
    return {};
  }

  // ─── Internal helpers ──────────────────────────────────────

  /// Sync any offline-queued requests.
  Future<void> _syncOfflineQueue() async {
    final pending = LocalDbService.getPendingRequests();
    if (pending.isEmpty) return;

    AppLogger.info('Syncing ${pending.length} offline requests', tag: 'NET');
    final failed = <Map<String, dynamic>>[];
    for (final req in pending) {
      try {
        await _client.from('requests').insert(req);
      } catch (_) {
        failed.add(req); // Track failures, keep syncing others
      }
    }
    await LocalDbService.clearPendingRequests();
    // Re-queue any that failed
    for (final req in failed) {
      await LocalDbService.queueOfflineRequest(req);
    }
    if (failed.isEmpty) {
      AppLogger.info('Offline queue synced', tag: 'NET');
    } else {
      AppLogger.warning('${failed.length}/${pending.length} requests still pending', tag: 'NET');
    }
  }
}
