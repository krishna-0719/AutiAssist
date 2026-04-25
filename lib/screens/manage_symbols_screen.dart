import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/service_providers.dart';
import '../providers/session_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/caregiver_nav_bar.dart';

/// Symbol management — searchable grid, add/edit/delete with image picker.
class ManageSymbolsScreen extends ConsumerStatefulWidget {
  const ManageSymbolsScreen({super.key});
  @override
  ConsumerState<ManageSymbolsScreen> createState() => _ManageSymbolsScreenState();
}

class _ManageSymbolsScreenState extends ConsumerState<ManageSymbolsScreen> {
  List<Map<String, dynamic>> _symbols = [];
  List<Map<String, dynamic>> _filtered = [];
  List<String> _rooms = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final q = _searchCtrl.text.trim().toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? List.from(_symbols)
            : _symbols.where((s) {
                final label = (s['label'] as String? ?? '').toLowerCase();
                final type = (s['type'] as String? ?? '').toLowerCase();
                return label.contains(q) || type.contains(q);
              }).toList();
      });
    });
  }

  Future<void> _loadData() async {
    final familyId = ref.read(familyIdProvider);
    if (familyId == null) {
      if (mounted) setState(() { _loading = false; _error = 'Session expired.'; });
      return;
    }
    setState(() => _loading = true);
    try {
      final symbols = await ref.read(symbolRepositoryProvider).getSymbols(familyId);
      final rooms = await ref.read(roomRepositoryProvider).getRooms(familyId);
      if (mounted) {
        setState(() {
          _symbols = symbols;
          _filtered = List.from(symbols);
          _rooms = rooms.map((r) => r.name).toList();
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Failed to load: $e'; });
    }
  }

  Future<void> _addSymbol() async {
    final familyId = ref.read(familyIdProvider);
    if (familyId == null) return;
    final result = await _showSymbolDialog();
    if (result == null) return;
    setState(() => _loading = true);
    try {
      String? imageUrl;
      if (result['imagePath'] != null && result['imagePath']!.isNotEmpty) {
        imageUrl = await ref.read(symbolRepositoryProvider)
            .uploadSymbolImage(familyId, result['type']!, result['imagePath']!);
      }
      await ref.read(symbolRepositoryProvider).addSymbol(
        familyId: familyId, type: result['type']!, label: result['label']!,
        emoji: result['emoji'], roomName: result['roomName'], imageUrl: imageUrl,
      );
    } finally { _loadData(); }
  }

  Future<void> _editSymbol(Map<String, dynamic> symbol) async {
    final familyId = ref.read(familyIdProvider);
    if (familyId == null) return;
    final result = await _showSymbolDialog(
      initialType: symbol['type'] as String?,
      initialLabel: symbol['label'] as String?,
      initialEmoji: symbol['emoji'] as String?,
      initialRoom: symbol['room_name'] as String?,
      initialImageUrl: symbol['image_url'] as String?,
    );
    if (result == null) return;
    setState(() => _loading = true);
    try {
      String? imageUrl = result['imageUrl'];
      if (result['imagePath'] != null && result['imagePath']!.isNotEmpty) {
        imageUrl = await ref.read(symbolRepositoryProvider)
            .uploadSymbolImage(familyId, symbol['type'] as String, result['imagePath']!);
      }
      await ref.read(symbolRepositoryProvider).updateSymbol(
        symbolId: symbol['id'] as String, label: result['label'],
        emoji: result['emoji'], roomName: result['roomName'], imageUrl: imageUrl,
      );
    } finally { _loadData(); }
  }

  Future<void> _deleteSymbol(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.cardRadius),
        title: const Text('Delete symbol?'),
        content: const Text('This removes the symbol permanently.', maxLines: 3, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loading = true);
    await ref.read(symbolRepositoryProvider).deleteSymbol(id);
    _loadData();
  }

  Future<Map<String, String?>?> _showSymbolDialog({
    String? initialType, String? initialLabel, String? initialEmoji,
    String? initialRoom, String? initialImageUrl,
  }) async {
    final typeCtrl = TextEditingController(text: initialType);
    final labelCtrl = TextEditingController(text: initialLabel);
    final emojiCtrl = TextEditingController(text: initialEmoji);
    String? selectedRoom = initialRoom;
    String? imagePath;

    return showDialog<Map<String, String?>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppTheme.cardRadius),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          contentPadding: const EdgeInsets.all(20),
          title: Text(initialType != null ? 'Edit Symbol' : 'Add Symbol',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width - 32,
              maxHeight: MediaQuery.of(context).size.height - 200,
            ),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (initialType == null)
                  TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: 'Type (e.g. "juice")')),
                if (initialType == null) const SizedBox(height: 12),
                TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'Label')),
                const SizedBox(height: 12),
                TextField(controller: emojiCtrl, decoration: const InputDecoration(labelText: 'Emoji (Fallback)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRoom,
                  decoration: const InputDecoration(labelText: 'Room (Optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Available Everywhere')),
                    ..._rooms.map((r) => DropdownMenuItem(value: r, child: Text(r))),
                  ],
                  onChanged: (val) => setD(() => selectedRoom = val),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  if (imagePath != null)
                    ClipRRect(borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(imagePath!), width: 56, height: 56, fit: BoxFit.cover))
                  else if (initialImageUrl != null)
                    ClipRRect(borderRadius: BorderRadius.circular(12),
                      child: Image.network(initialImageUrl, width: 56, height: 56, fit: BoxFit.cover))
                  else
                    Container(width: 56, height: 56,
                      decoration: BoxDecoration(color: AppTheme.shimmerBase, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.image_rounded, color: AppTheme.textLight)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(children: [
                    SizedBox(width: double.infinity, child: OutlinedButton.icon(
                      onPressed: () async {
                        final file = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 512, maxHeight: 512, imageQuality: 85);
                        if (file != null) setD(() => imagePath = file.path);
                      },
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text('Camera', maxLines: 1, overflow: TextOverflow.ellipsis),
                    )),
                    const SizedBox(height: 6),
                    SizedBox(width: double.infinity, child: OutlinedButton.icon(
                      onPressed: () async {
                        final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
                        if (file != null) setD(() => imagePath = file.path);
                      },
                      icon: const Icon(Icons.photo_library_rounded, size: 18),
                      label: const Text('Gallery', maxLines: 1, overflow: TextOverflow.ellipsis),
                    )),
                  ])),
                ]),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, {
                'type': typeCtrl.text.trim().isNotEmpty ? typeCtrl.text.trim() : (initialType ?? ''),
                'label': labelCtrl.text.trim(), 'emoji': emojiCtrl.text.trim(),
                'roomName': selectedRoom, 'imagePath': imagePath, 'imageUrl': initialImageUrl,
              }),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isTablet = media.size.width >= AppTheme.tabletBreakpoint;
    final padding = isTablet ? AppTheme.screenPaddingTablet : AppTheme.screenPaddingMobile;
    final crossAxisCount = isTablet ? 3 : 2;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/dashboard');
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        bottomNavigationBar: const CaregiverNavBar(currentIndex: 3),
      floatingActionButton: FloatingActionButton(
        heroTag: 'symbols_fab',
        onPressed: _addSymbol,
        backgroundColor: AppTheme.caregiverPrimary,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
              child: Text('Symbols', style: GoogleFonts.outfit(
                fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.textDark),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ).animate().fadeIn(duration: 400.ms),
            const SizedBox(height: 16),
            // Search bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: Semantics(
                textField: true,
                label: 'Search symbols',
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search symbols…',
                    prefixIcon: const Icon(Icons.search_rounded, size: 22),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () { _searchCtrl.clear(); _onSearch(); })
                        : null,
                    filled: true, fillColor: AppTheme.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
            const SizedBox(height: 16),
            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.caregiverPrimary))
                  : _error != null
                      ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
                          mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.statusError),
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: () async {
                              await ref.read(sessionProvider.notifier).clearSession();
                              if (!context.mounted) return;
                              context.go('/role-select');
                            }, child: const Text('Sign in again')),
                          ])))
                      : _filtered.isEmpty
                          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.grid_view_rounded, size: 56, color: AppTheme.textLight.withValues(alpha: 0.5)),
                              const SizedBox(height: 16),
                              Text(_searchCtrl.text.isNotEmpty ? 'No matching symbols' : 'No symbols yet',
                                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMedium),
                                maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                              const SizedBox(height: 8),
                              const Text('Tap + to add your first symbol',
                                style: TextStyle(color: AppTheme.textLight, fontSize: 14)),
                            ]))
                          : GridView.builder(
                              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                              padding: EdgeInsets.fromLTRB(padding, 0, padding, 100),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 12, mainAxisSpacing: 12,
                                childAspectRatio: 0.85,
                              ),
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) => _SymbolGridCard(
                                symbol: _filtered[i], index: i,
                                onEdit: () => _editSymbol(_filtered[i]),
                                onDelete: () => _deleteSymbol(_filtered[i]['id'] as String),
                              ),
                            ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _SymbolGridCard extends StatelessWidget {
  final Map<String, dynamic> symbol;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _SymbolGridCard({required this.symbol, required this.index, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final hasImage = symbol['image_url'] != null;
    final label = symbol['label'] as String? ?? '';
    final type = symbol['type'] as String? ?? '';
    final room = symbol['room_name'] as String?;

    return Semantics(
      label: 'Symbol $label, type $type',
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.softShadow,
          border: Border.all(color: AppTheme.cardBorder.withValues(alpha: 0.4)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasImage)
                    ClipRRect(borderRadius: BorderRadius.circular(14),
                      child: Image.network(symbol['image_url'], width: 56, height: 56, fit: BoxFit.cover))
                  else
                    Text(symbol['emoji'] as String? ?? '✨', style: const TextStyle(fontSize: 40)),
                  const SizedBox(height: 10),
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Flexible(child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.caregiverPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6)),
                      child: Text(type, style: const TextStyle(fontSize: 10, color: AppTheme.caregiverPrimary, fontWeight: FontWeight.w700),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    )),
                    if (room != null) ...[
                      const SizedBox(width: 4),
                      Flexible(child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6)),
                        child: Text(room, style: const TextStyle(fontSize: 10, color: AppTheme.accent, fontWeight: FontWeight.w700),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      )),
                    ],
                  ]),
                  const Spacer(),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(width: 36, height: 36, child: IconButton(
                      iconSize: 18, padding: EdgeInsets.zero,
                      icon: const Icon(Icons.edit_rounded, color: AppTheme.accent),
                      onPressed: onEdit)),
                    if (symbol['id'] != null)
                      SizedBox(width: 36, height: 36, child: IconButton(
                        iconSize: 18, padding: EdgeInsets.zero,
                        icon: const Icon(Icons.delete_rounded, color: AppTheme.danger),
                        onPressed: onDelete)),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: (50 * index).ms, duration: 300.ms)
        .scale(begin: const Offset(0.92, 0.92), curve: Curves.easeOutBack);
  }
}
