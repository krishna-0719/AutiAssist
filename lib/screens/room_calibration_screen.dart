import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/service_providers.dart';
import '../providers/session_provider.dart';
import '../models/room_model.dart';
import '../theme/app_theme.dart';

/// Premium WiFi calibration screen & Room Management.
class RoomCalibrationScreen extends ConsumerStatefulWidget {
  const RoomCalibrationScreen({super.key});
  @override
  ConsumerState<RoomCalibrationScreen> createState() => _RoomCalibrationScreenState();
}

class _RoomCalibrationScreenState extends ConsumerState<RoomCalibrationScreen> {
  List<RoomModel> _allRooms = [];
  Map<String, int> _calibratedRooms = {};
  String? _scanningRoomName;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadCalibrations();
  }

  Future<void> _loadCalibrations() async {
    final familyId = ref.read(familyIdProvider);
    if (familyId != null) {
      _allRooms = await ref.read(roomRepositoryProvider).getRooms(familyId);
    }
    
    final envService = ref.read(environmentServiceProvider);
    _calibratedRooms = await envService.getCalibratedRooms();
    
    if (mounted) setState(() {});
  }

  Future<void> _addRoom() async {
    final familyId = ref.read(familyIdProvider);
    if (familyId == null) return;

    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.cardRadius),
        title: const Text('Add Room'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Room Name', hintText: 'e.g., Kitchen'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      await ref.read(roomRepositoryProvider).addRoom(familyId: familyId, name: name);
      await _loadCalibrations();
    }
  }

  Future<void> _toggleCalibration(String roomName) async {
    if (_scanningRoomName == roomName) {
      setState(() { _scanningRoomName = null; _statusMessage = '✅ Calibration stopped for $roomName.'; });
      return;
    } else if (_scanningRoomName != null) {
      setState(() => _statusMessage = 'Stop scanning $_scanningRoomName first.');
      return;
    }
    
    setState(() { _scanningRoomName = roomName; _statusMessage = 'Scanning $roomName (Walk around)...'; });

    final envService = ref.read(environmentServiceProvider);
    
    while (_scanningRoomName == roomName && mounted) {
      try {
        await envService.saveRoomFingerprint(roomName);
        if (_scanningRoomName == roomName && mounted) {
          await _loadCalibrations();
        }
      } catch (e) {
        if (_scanningRoomName == roomName && mounted) {
          setState(() { _scanningRoomName = null; _statusMessage = '❌ Scan failed: $e'; });
        }
        break;
      }
    }
  }

  Future<void> _deleteRoom(RoomModel room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete room?'),
        content: Text('Delete "${room.name}" and all its calibration data?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(roomRepositoryProvider).deleteRoom(room.id);
    await ref.read(environmentServiceProvider).deleteRoom(room.name);
    await _loadCalibrations();
  }

  @override
  void dispose() {
    _scanningRoomName = null; // Stop scanning if navigating away
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text('Rooms & Calibration', style: GoogleFonts.outfit(fontWeight: FontWeight.w800))),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRoom,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: Column(
        children: [
          if (_statusMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _statusMessage!.contains('✅')
                      ? AppTheme.success.withValues(alpha: 0.08)
                      : (_statusMessage!.contains('❌') ? AppTheme.danger.withValues(alpha: 0.08) : AppTheme.warning.withValues(alpha: 0.08)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_statusMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _statusMessage!.contains('✅') 
                          ? AppTheme.success 
                          : (_statusMessage!.contains('❌') ? AppTheme.danger : AppTheme.textMedium),
                      fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
            
          Expanded(
            child: _allRooms.isEmpty
              ? const Center(child: Text('No rooms added yet. Tap + to add a room.', style: TextStyle(color: AppTheme.textMedium)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80), // Padding for FAB
                  itemCount: _allRooms.length,
                  itemBuilder: (_, i) {
                    final room = _allRooms[i];
                    final isScanning = _scanningRoomName == room.name;
                    final fpCount = _calibratedRooms[room.name] ?? 0;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: AppTheme.cardRadius,
                        border: Border.all(color: isScanning ? AppTheme.accent : AppTheme.success.withValues(alpha: 0.15)),
                        boxShadow: isScanning ? AppTheme.coloredShadow(AppTheme.accent) : AppTheme.softShadow,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.room_rounded, color: AppTheme.success, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(room.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text('$fpCount calibration point${fpCount == 1 ? '' : 's'}',
                                        style: TextStyle(fontSize: 12, color: fpCount > 0 ? AppTheme.success : AppTheme.textMedium, fontWeight: fpCount > 0 ? FontWeight.w600 : FontWeight.normal)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_rounded, color: AppTheme.danger),
                                onPressed: () => _deleteRoom(room),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => _toggleCalibration(room.name),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: isScanning ? AppTheme.darkGradient : AppTheme.coolGradient,
                                borderRadius: AppTheme.pillRadius,
                              ),
                              child: Center(
                                child: isScanning
                                    ? const Row(mainAxisSize: MainAxisSize.min, children: [
                                        SizedBox(width: 16, height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                        SizedBox(width: 10),
                                        Text('Stop Scanning', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                      ])
                                    : Row(mainAxisSize: MainAxisSize.min, children: [
                                        const Icon(Icons.wifi_rounded, color: Colors.white, size: 18),
                                        const SizedBox(width: 8),
                                        Text(fpCount > 0 ? 'Scan More Points' : 'Start Calibration Scan', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                                      ]),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: Duration(milliseconds: 50 * i)).slideY(begin: 0.1);
                  },
                ),
          ),
        ],
      ),
    );
  }
}
