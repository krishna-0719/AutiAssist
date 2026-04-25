import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/local_db_service.dart';
import '../../utils/app_exceptions.dart';
import '../../utils/app_logger.dart';

/// Handles symbol CRUD with local Hive caching for offline access.
class SymbolRepository {
  final SupabaseClient _client;

  SymbolRepository(this._client);

  /// Default symbols when no custom symbols are configured.
  static const List<Map<String, dynamic>> defaultSymbols = [
    {'type': 'water', 'label': 'Water', 'emoji': '💧'},
    {'type': 'food', 'label': 'Food', 'emoji': '🍽️'},
    {'type': 'bathroom', 'label': 'Bathroom', 'emoji': '🚻'},
    {'type': 'help', 'label': 'Help', 'emoji': '🆘'},
    {'type': 'play', 'label': 'Play', 'emoji': '🧸'},
    {'type': 'sleep', 'label': 'Sleep', 'emoji': '😴'},
    {'type': 'music', 'label': 'Music', 'emoji': '🎵'},
    {'type': 'hug', 'label': 'Hug', 'emoji': '🤗'},
    {'type': 'outside', 'label': 'Go Outside', 'emoji': '🌳'},
    {'type': 'pain', 'label': 'Pain', 'emoji': '🤕'},
  ];

  /// Get symbols for a family, with Hive cache fallback.
  Future<List<Map<String, dynamic>>> getSymbols(String familyId) async {
    try {
      final response = await _client
          .from('symbols')
          .select()
          .eq('family_id', familyId)
          .order('created_at')
          .timeout(const Duration(seconds: 4));
      final symbols = List<Map<String, dynamic>>.from(response as List);
      // Cache for offline
      await LocalDbService.cacheSymbols(symbols);
      return symbols.isNotEmpty ? symbols : defaultSymbols;
    } catch (e) {
      AppLogger.warning('Symbol fetch failed, using cache', tag: 'SYM');
      final cached = LocalDbService.getCachedSymbols();
      return cached.isNotEmpty ? cached : defaultSymbols;
    }
  }

  /// Add a new symbol.
  Future<Map<String, dynamic>> addSymbol({
    required String familyId,
    required String type,
    required String label,
    String? emoji,
    String? color,
    String? roomName,
    String? imageUrl,
  }) async {
    try {
      final data = {
        'family_id': familyId,
        'type': type.toLowerCase().trim(),
        'label': label.trim(),
        'emoji': emoji ?? '✨',
        if (color != null) 'color': color,
        if (roomName != null && roomName.isNotEmpty) 'room_name': roomName,
        if (imageUrl != null) 'image_url': imageUrl,
      };
      final response = await _client
          .from('symbols')
          .insert(data)
          .select()
          .single();
      AppLogger.info('Symbol added: $type', tag: 'SYM');
      return response;
    } catch (e) {
      throw DataException('Failed to add symbol: $e', originalError: e);
    }
  }

  /// Update an existing symbol.
  Future<void> updateSymbol({
    required String symbolId,
    String? label,
    String? emoji,
    String? color,
    String? roomName,
    String? imageUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (label != null) updates['label'] = label.trim();
      if (emoji != null) updates['emoji'] = emoji;
      if (color != null) updates['color'] = color;
      if (roomName != null) updates['room_name'] = roomName.isEmpty ? null : roomName;
      if (imageUrl != null) updates['image_url'] = imageUrl;

      if (updates.isNotEmpty) {
        await _client.from('symbols').update(updates).eq('id', symbolId);
        AppLogger.info('Symbol updated: $symbolId', tag: 'SYM');
      }
    } catch (e) {
      throw DataException('Failed to update symbol: $e', originalError: e);
    }
  }

  /// Delete a symbol.
  Future<void> deleteSymbol(String symbolId) async {
    try {
      await _client.from('symbols').delete().eq('id', symbolId);
      AppLogger.info('Symbol deleted: $symbolId', tag: 'SYM');
    } catch (e) {
      throw DataException('Failed to delete symbol: $e', originalError: e);
    }
  }

  Future<String> uploadSymbolImage(String familyId, String symbolType, String filePath) async {
    try {
      final file = File(filePath);
      final ext = filePath.split('.').last;
      final fileName = '${familyId}_${symbolType}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      
      await _client.storage.from('symbols').upload(
        fileName,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );
      
      final publicUrl = _client.storage.from('symbols').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      AppLogger.error('Failed to upload symbol image: $e', tag: 'SYM');
      throw DataException('Failed to upload symbol image: $e', originalError: e);
    }
  }
}
