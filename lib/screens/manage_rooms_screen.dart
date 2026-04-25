import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../providers/service_providers.dart';
import '../providers/session_provider.dart';
import '../models/room_model.dart';
import '../theme/app_theme.dart';

/// Manage rooms screen — add/delete rooms.
class ManageRoomsScreen extends ConsumerStatefulWidget {
  const ManageRoomsScreen({super.key});
  @override
  ConsumerState<ManageRoomsScreen> createState() => _ManageRoomsScreenState();
}

class _ManageRoomsScreenState extends ConsumerState<ManageRoomsScreen> {
  List<RoomModel> _rooms = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    final familyId = ref.read(familyIdProvider);
    if (familyId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Session expired. Please sign in again.';
        });
      }
      return;
    }
    setState(() => _loading = true);
    _rooms = await ref.read(roomRepositoryProvider).getRooms(familyId);
    if (mounted) {
      setState(() { _loading = false; _error = null; });
    }
  }

  Future<void> _recoverSession() async {
    await ref.read(sessionProvider.notifier).clearSession();
    if (mounted) context.go('/role-select');
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
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Room Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    await ref.read(roomRepositoryProvider).addRoom(familyId: familyId, name: name);
    _loadRooms();
  }

  Future<void> _deleteRoom(String roomId) async {
    await ref.read(roomRepositoryProvider).deleteRoom(roomId);
    _loadRooms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text('Manage Rooms', style: GoogleFonts.outfit(fontWeight: FontWeight.w800))),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRoom,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_reset_rounded, size: 48, color: AppTheme.primary),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _recoverSession, child: const Text('Go to sign in')),
                      ],
                    ),
                  ),
                )
          : _rooms.isEmpty
              ? const Center(child: Text('No rooms yet. Tap + to add one.', style: TextStyle(color: AppTheme.textLight)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rooms.length,
                  itemBuilder: (_, i) {
                    final room = _rooms[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface, borderRadius: AppTheme.cardRadius, boxShadow: AppTheme.softShadow),
                      child: Row(
                        children: [
                          const Icon(Icons.room_rounded, color: AppTheme.primary),
                          const SizedBox(width: 14),
                          Expanded(child: Text(room.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                          IconButton(
                            icon: const Icon(Icons.delete_rounded, color: AppTheme.danger),
                            onPressed: () => _deleteRoom(room.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
