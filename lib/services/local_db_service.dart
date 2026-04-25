import 'dart:convert';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/app_logger.dart';

/// Hive-based local database service for offline caching and persistence.
class LocalDbService {
  LocalDbService._();

  static late Box _appBox;
  static late Box _behaviorBox;
  static bool _initialized = false;

  // ─── Initialization ──────────────────────────────────────
  static Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _appBox = await Hive.openBox('appData');
    _behaviorBox = await Hive.openBox('behavior_cache');
    _initialized = true;
    AppLogger.info('Hive initialized', tag: 'DB');
  }

  // ─── Session ─────────────────────────────────────────────
  static String? get savedRole => _appBox.get('role') as String?;
  static String? get savedFamilyCode => _appBox.get('familyCode') as String?;
  static String? get savedFamilyId => _appBox.get('familyId') as String?;

  static Future<void> saveSession({
    required String role,
    required String familyCode,
    required String familyId,
  }) async {
    await _appBox.put('role', role);
    await _appBox.put('familyCode', familyCode);
    await _appBox.put('familyId', familyId);
  }

  static Future<void> clearSession() async {
    await _appBox.delete('role');
    await _appBox.delete('familyCode');
    await _appBox.delete('familyId');
  }

  // ─── Symbol Cache ────────────────────────────────────────
  static Future<void> cacheSymbols(List<Map<String, dynamic>> symbols) async {
    await _appBox.put('cachedSymbols', jsonEncode(symbols));
  }

  static List<Map<String, dynamic>> getCachedSymbols() {
    final raw = _appBox.get('cachedSymbols') as String?;
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Symbol Image Paths ──────────────────────────────────
  static Future<void> saveSymbolImagePath(String typeId, String path) async {
    await _appBox.put('symbolImage_$typeId', path);
  }

  static String? getSymbolImagePath(String typeId) {
    return _appBox.get('symbolImage_$typeId') as String?;
  }

  /// Returns the local directory for storing symbol images.
  static Future<String> get symbolImageDir async {
    final dir = await getApplicationDocumentsDirectory();
    final imgDir = Directory('${dir.path}/symbol_images');
    if (!await imgDir.exists()) await imgDir.create(recursive: true);
    return imgDir.path;
  }

  // ─── Offline Request Queue ───────────────────────────────
  static Future<void> queueOfflineRequest(Map<String, dynamic> request) async {
    final list = _appBox.get('pendingRequests', defaultValue: <dynamic>[]) as List;
    list.add(jsonEncode(request));
    await _appBox.put('pendingRequests', list);
    AppLogger.info('Request queued offline (${list.length} pending)', tag: 'NET');
  }

  static List<Map<String, dynamic>> getPendingRequests() {
    final list = _appBox.get('pendingRequests', defaultValue: <dynamic>[]) as List;
    return list.map((e) {
      try {
        return Map<String, dynamic>.from(jsonDecode(e as String) as Map);
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((m) => m.isNotEmpty).toList();
  }

  static Future<void> clearPendingRequests() async {
    await _appBox.put('pendingRequests', <dynamic>[]);
  }

  // ─── Behavior Cache ──────────────────────────────────────
  static Future<void> cachePrediction(String key, Map<String, dynamic> data) async {
    data['_cachedAt'] = DateTime.now().millisecondsSinceEpoch;
    await _behaviorBox.put(key, jsonEncode(data));
  }

  static Map<String, dynamic>? getCachedPrediction(String key, {int ttlMinutes = 30}) {
    final raw = _behaviorBox.get(key) as String?;
    if (raw == null) return null;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final cachedAt = data['_cachedAt'] as int?;
      if (cachedAt != null) {
        final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
        if (age > ttlMinutes * 60 * 1000) return null; // expired
      }
      return data;
    } catch (_) {
      return null;
    }
  }

  // ─── Offline Behavior Logs ───────────────────────────────
  static Future<void> queueBehaviorLog(Map<String, dynamic> log) async {
    final list = _behaviorBox.get('pendingLogs', defaultValue: <dynamic>[]) as List;
    list.add(jsonEncode(log));
    await _behaviorBox.put('pendingLogs', list);
  }

  static List<Map<String, dynamic>> getPendingBehaviorLogs() {
    final list = _behaviorBox.get('pendingLogs', defaultValue: <dynamic>[]) as List;
    return list.map((e) {
      try {
        return Map<String, dynamic>.from(jsonDecode(e as String) as Map);
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((m) => m.isNotEmpty).toList();
  }

  static Future<void> clearPendingBehaviorLogs() async {
    await _behaviorBox.put('pendingLogs', <dynamic>[]);
  }
}
