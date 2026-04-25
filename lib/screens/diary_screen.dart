import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../models/entry_model.dart';
import '../providers/service_providers.dart';
import '../providers/session_provider.dart';
import '../theme/app_theme.dart';

/// Caregiver diary — timeline-style journal entries with CRUD.
class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});
  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  List<EntryModel> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final familyId = ref.read(familyIdProvider);
    if (familyId == null) {
      if (mounted) setState(() { _loading = false; _error = 'Session expired.'; });
      return;
    }
    setState(() => _loading = true);
    try {
      _entries = await ref.read(entryRepositoryProvider).getEntries(familyId);
      if (mounted) setState(() { _loading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Failed to load: $e'; });
    }
  }

  Future<void> _addEntry() async {
    final familyId = ref.read(familyIdProvider);
    if (familyId == null) return;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.cardRadius),
        title: Text('New Entry', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, maxLines: 4,
                decoration: const InputDecoration(labelText: 'Notes (optional)', alignLabelWithHint: true)),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (result != true || titleCtrl.text.trim().isEmpty) return;
    await ref.read(entryRepositoryProvider).addEntry(
      familyId: familyId, title: titleCtrl.text.trim(),
      description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
    );
    _loadEntries();
  }

  Future<void> _deleteEntry(String id) async {
    await ref.read(entryRepositoryProvider).deleteEntry(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry deleted'), behavior: SnackBarBehavior.floating),
      );
    }
    _loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isTablet = media.size.width >= AppTheme.tabletBreakpoint;
    final padding = isTablet ? AppTheme.screenPaddingTablet : AppTheme.screenPaddingMobile;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Diary', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'diary_fab',
        onPressed: _addEntry,
        backgroundColor: AppTheme.caregiverPrimary,
        child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 28),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.caregiverPrimary))
          : _error != null
              ? _DiaryError(error: _error!, onRecover: () async {
                  await ref.read(sessionProvider.notifier).clearSession();
                  if (!context.mounted) return;
                  context.go('/role-select');
                })
              : _entries.isEmpty
                  ? _DiaryEmpty(onAdd: _addEntry)
                  : RefreshIndicator(
                      onRefresh: _loadEntries,
                      color: AppTheme.caregiverPrimary,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        padding: EdgeInsets.fromLTRB(padding, 8, padding, 100),
                        itemCount: _entries.length,
                        itemBuilder: (_, i) {
                          final entry = _entries[i];
                          return _DiaryCard(
                            entry: entry,
                            index: i,
                            onDelete: () => _deleteEntry(entry.id),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _DiaryCard extends StatelessWidget {
  final EntryModel entry;
  final int index;
  final VoidCallback onDelete;
  const _DiaryCard({required this.entry, required this.index, required this.onDelete});

  static const _accentColors = [
    AppTheme.caregiverPrimary, AppTheme.secondary,
    AppTheme.accent, AppTheme.orange, AppTheme.pink,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _accentColors[index % _accentColors.length];

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_rounded, color: AppTheme.danger, size: 24),
      ),
      onDismissed: (_) => onDelete(),
      child: Semantics(
        label: '${entry.title}, ${entry.dateLabel}',
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.softShadow,
            border: Border.all(color: AppTheme.cardBorder.withValues(alpha: 0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline accent bar
              Container(
                width: 4,
                height: 80,
                margin: const EdgeInsets.only(left: 0),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.title,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: AppTheme.pillRadius,
                            ),
                            child: Text(
                              entry.dateLabel,
                              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (entry.description != null && entry.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          entry.description!,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textMedium, height: 1.4),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (60 * index).ms, duration: 300.ms)
        .slideX(begin: 0.05, curve: Curves.easeOut);
  }
}

class _DiaryEmpty extends StatelessWidget {
  final VoidCallback onAdd;
  const _DiaryEmpty({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.shimmerBase.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.book_rounded, size: 48, color: AppTheme.textLight),
            ),
            const SizedBox(height: 20),
            Text('No diary entries yet',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMedium),
              textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Start documenting your child\'s progress',
              style: TextStyle(color: AppTheme.textLight, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Write First Entry'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.caregiverPrimary),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms);
  }
}

class _DiaryError extends StatelessWidget {
  final String error;
  final VoidCallback onRecover;
  const _DiaryError({required this.error, required this.onRecover});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.statusError),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRecover, child: const Text('Sign in again')),
          ],
        ),
      ),
    );
  }
}
