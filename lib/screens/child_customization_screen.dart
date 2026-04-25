import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/service_providers.dart';
import '../providers/session_provider.dart';
import '../theme/app_theme.dart';

class ChildCustomizationScreen extends ConsumerStatefulWidget {
  const ChildCustomizationScreen({super.key});
  @override
  ConsumerState<ChildCustomizationScreen> createState() => _ChildCustomizationScreenState();
}

class _ChildCustomizationScreenState extends ConsumerState<ChildCustomizationScreen> {
  List<Map<String, dynamic>> _symbols = [];
  Set<String> _hiddenSymbols = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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
    final symbols = await ref.read(symbolRepositoryProvider).getSymbols(familyId);
    
    final prefs = await SharedPreferences.getInstance();
    final hiddenList = prefs.getStringList('hidden_symbols') ?? [];
    
    setState(() {
      _symbols = symbols;
      _hiddenSymbols = hiddenList.toSet();
      _loading = false;
      _error = null;
    });
  }

  Future<void> _recoverSession() async {
    await ref.read(sessionProvider.notifier).clearSession();
    if (mounted) context.go('/role-select');
  }

  Future<void> _toggleHidden(String typeId) async {
    setState(() {
      if (_hiddenSymbols.contains(typeId)) {
        _hiddenSymbols.remove(typeId);
      } else {
        _hiddenSymbols.add(typeId);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('hidden_symbols', _hiddenSymbols.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text('Customize Layout', style: GoogleFonts.outfit(fontWeight: FontWeight.w800))),
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
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _symbols.length,
              itemBuilder: (_, i) {
                final s = _symbols[i];
                final typeId = s['type'] as String? ?? '';
                final isHidden = _hiddenSymbols.contains(typeId);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isHidden ? AppTheme.surface.withValues(alpha: 0.5) : AppTheme.surface, 
                    borderRadius: AppTheme.cardRadius, 
                    boxShadow: AppTheme.softShadow),
                  child: Row(
                    children: [
                      Text(s['emoji'] as String? ?? '✨', style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s['label'] as String? ?? '', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, decoration: isHidden ? TextDecoration.lineThrough : null)),
                          Text(typeId, style: const TextStyle(fontSize: 12, color: AppTheme.textMedium)),
                        ],
                      )),
                      IconButton(
                        icon: Icon(isHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: isHidden ? AppTheme.textMedium : AppTheme.primary), 
                        onPressed: () => _toggleHidden(typeId),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
