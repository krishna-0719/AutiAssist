import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/room_detection_provider.dart';
import '../providers/service_providers.dart';
import '../providers/session_provider.dart';
import '../providers/symbols_provider.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../widgets/symbol_card.dart';
import '../widgets/math_lock_dialog.dart';

class ChildScreen extends ConsumerStatefulWidget {
  const ChildScreen({super.key});

  @override
  ConsumerState<ChildScreen> createState() => _ChildScreenState();
}

class _ChildScreenState extends ConsumerState<ChildScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _selectedSymbol;
  List<Map<String, dynamic>> _suggestedSymbols = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roomDetectionProvider.notifier).startScanning();
      _loadSuggestions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      ref.read(roomDetectionProvider.notifier).stopScanning();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(roomDetectionProvider.notifier).startScanning();
      _loadSuggestions();
    }
  }

  Future<void> _loadSuggestions() async {
    final familyId = ref.read(familyIdProvider);
    final roomState = ref.read(roomDetectionProvider);
    if (familyId == null || roomState.currentRoom == 'Detecting...') {
      return;
    }

    final preds = await ref.read(behaviorServiceProvider).getPredictions(
          familyId: familyId,
          room: roomState.currentRoom,
        );
    if (!mounted) {
      return;
    }

    final allSymbols = ref.read(symbolsProvider).valueOrNull ?? <Map<String, dynamic>>[];
    final predictedTypes = preds
        .map((e) => (e['type'] as String?) ?? '')
        .where((e) => e.isNotEmpty)
        .toSet();

    setState(() {
      _suggestedSymbols = allSymbols
          .where((symbol) => predictedTypes.contains((symbol['type'] as String?) ?? ''))
          .take(8)
          .toList();
    });
  }

  Future<void> _sendRequest() async {
    final selected = _selectedSymbol;
    final familyId = ref.read(familyIdProvider);
    final room = ref.read(roomDetectionProvider).currentRoom;

    if (selected == null || familyId == null) {
      return;
    }

    final type = (selected['type'] as String?) ?? '';
    final label = (selected['label'] as String?) ?? 'Request';
    if (type.isEmpty) {
      return;
    }

    HapticFeedback.lightImpact();
    await TtsService.speak('I want $label');

    await ref.read(requestRepositoryProvider).createRequest(
          type: type,
          room: room,
          familyId: familyId,
        );

    await ref.read(behaviorServiceProvider).logTap(
          familyId: familyId,
          userId: ref.read(supabaseServiceProvider).userId ?? 'anonymous',
          symbolType: type,
          room: room,
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedSymbol = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Request sent: $label',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Future<void> _sendEmergency(String label, String emoji) async {
    final familyId = ref.read(familyIdProvider);
    final room = ref.read(roomDetectionProvider).currentRoom;

    if (familyId == null) {
      return;
    }

    HapticFeedback.heavyImpact();
    await TtsService.speak('I need $label');

    await ref.read(requestRepositoryProvider).createRequest(
          type: 'Emergency: $label',
          room: room,
          familyId: familyId,
        );

    await ref.read(behaviorServiceProvider).logTap(
          familyId: familyId,
          userId: ref.read(supabaseServiceProvider).userId ?? 'anonymous',
          symbolType: 'emergency',
          room: room,
        );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.danger,
        content: Text(
          'Emergency sent: $label',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _openSettingsSheet() async {
    // Require parental math lock before accessing settings
    final unlocked = await MathLockDialog.show(context);
    if (!unlocked) return;

    if (!mounted) return;
    
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.screenPaddingMobile),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.textLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                ListTile(
                  minVerticalPadding: 12,
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text(
                    'Customize symbols',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/child-customize');
                  },
                ),
                ListTile(
                  minVerticalPadding: 12,
                  leading: const Icon(Icons.wifi_find_rounded),
                  title: const Text(
                    'Recalibrate rooms',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/room-calibration');
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  int _gridCount(double width) {
    if (width >= AppTheme.desktopBreakpoint) {
      return 5;
    }
    if (width >= AppTheme.tabletBreakpoint) {
      return 4;
    }
    // Return 2 columns for mobile to make icons large and tappable
    return 2;
  }

  Color _symbolColor(int index) {
    const palette = <Color>[
      AppTheme.childBlue,
      AppTheme.childPink,
      AppTheme.childYellow,
      AppTheme.childGreen,
    ];
    return palette[index % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final symbolsAsync = ref.watch(symbolsProvider);
    final roomState = ref.watch(roomDetectionProvider);
    final media = MediaQuery.of(context);
    final textScale = media.textScaler.scale(1.0).clamp(1.0, 2.0);
    final horizontalPadding = media.size.width >= AppTheme.tabletBreakpoint
        ? AppTheme.screenPaddingTablet
        : 24.0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 8),
              child: Row(
                children: [
                  Semantics(
                    label: 'Current room ${roomState.currentRoom}',
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 40),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surface.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.home_work_rounded, size: 18),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: media.size.width * 0.45),
                            child: Text(
                              roomState.currentRoom,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 12 * textScale,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    button: true,
                    label: 'Open child settings',
                    child: IconButton(
                      iconSize: 28,
                      onPressed: _openSettingsSheet,
                      icon: const Icon(Icons.settings_rounded),
                    ),
                  ),
                ],
              ),
            ),
            
            // EMERGENCY SECTION
            Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 8),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded, color: AppTheme.danger, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Emergency',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.danger,
                        ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _EmergencyButton(label: 'Help', emoji: '🚨', onTap: () => _sendEmergency('Help', '🚨')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _EmergencyButton(label: 'Pain', emoji: '🤕', onTap: () => _sendEmergency('Pain', '🤕')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _EmergencyButton(label: 'Water', emoji: '💧', onTap: () => _sendEmergency('Water', '💧')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _EmergencyButton(label: 'Toilet', emoji: '🚽', onTap: () => _sendEmergency('Toilet', '🚽')),
                  ),
                ],
              ),
            ),

            Expanded(
              child: symbolsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _ErrorState(
                  message: 'Could not load symbols. Pull to retry.',
                  onRetry: () => ref.invalidate(symbolsProvider),
                ),
                data: (symbols) {
                  if (symbols.isEmpty) {
                    return _ErrorState(
                      message: 'No symbols available yet.',
                      onRetry: () => ref.invalidate(symbolsProvider),
                    );
                  }

                  // Sort symbols: Current room first, then global, then other rooms
                  final sortedSymbols = List<Map<String, dynamic>>.from(symbols);
                  sortedSymbols.sort((a, b) {
                    final roomA = (a['room_name'] as String?)?.trim().toLowerCase() ?? '';
                    final roomB = (b['room_name'] as String?)?.trim().toLowerCase() ?? '';
                    final current = roomState.currentRoom.toLowerCase();
                    
                    int scoreA = roomA == current ? 0 : (roomA == '' ? 1 : 2);
                    int scoreB = roomB == current ? 0 : (roomB == '' ? 1 : 2);
                    
                    return scoreA.compareTo(scoreB);
                  });

                  final listForGrid = sortedSymbols;

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(symbolsProvider);
                      await _loadSuggestions();
                    },
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = _gridCount(constraints.maxWidth);
                        const spacing = 16.0;
                        final cardWidth = (constraints.maxWidth - (horizontalPadding * 2) -
                                ((crossAxisCount - 1) * spacing)) /
                            crossAxisCount;
                        final cardHeight = math.max(AppTheme.minSymbolCardSize, cardWidth * 1.08);

                        return ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            8,
                            horizontalPadding,
                            120,
                          ),
                          children: [
                            if (_suggestedSymbols.isNotEmpty) ...[
                              Text(
                                '✨ Suggested',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.caregiverPrimary,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 122,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: _suggestedSymbols.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                                  itemBuilder: (context, index) {
                                    final symbol = _suggestedSymbols[index];
                                    final selected = identical(_selectedSymbol, symbol);
                                    return SizedBox(
                                      width: 160,
                                      child: Semantics(
                                        button: true,
                                        label: 'Suggested symbol ${(symbol['label'] as String?) ?? 'Unknown'}',
                                        child: SymbolCard(
                                          label: (symbol['label'] as String?) ?? 'Unknown',
                                          emoji: (symbol['emoji'] as String?) ?? '✨',
                                          imageUrl: symbol['image_url'] as String?,
                                          isSuggested: true,
                                          accentColor: selected ? AppTheme.caregiverPrimary : AppTheme.childBlue,
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            setState(() {
                                              _selectedSymbol = symbol;
                                            });
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: AppTheme.sectionSpacing),
                            ],
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: listForGrid.length,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: spacing,
                                mainAxisSpacing: spacing,
                                mainAxisExtent: cardHeight,
                              ),
                              itemBuilder: (context, index) {
                                final symbol = listForGrid[index];
                                final isSelected = identical(_selectedSymbol, symbol);
                                return Semantics(
                                  button: true,
                                  label: 'Symbol ${(symbol['label'] as String?) ?? 'Unknown'}',
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minWidth: AppTheme.minSymbolCardSize,
                                      minHeight: AppTheme.minSymbolCardSize,
                                    ),
                                    child: SymbolCard(
                                      label: (symbol['label'] as String?) ?? 'Unknown',
                                      emoji: (symbol['emoji'] as String?) ?? '✨',
                                      imageUrl: symbol['image_url'] as String?,
                                      accentColor: isSelected
                                          ? AppTheme.caregiverPrimary
                                          : _symbolColor(index),
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() {
                                          _selectedSymbol = symbol;
                                        });
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 12),
          child: Semantics(
            button: true,
            label: _selectedSymbol == null
                ? 'Select a symbol first'
                : 'Send ${( _selectedSymbol?['label'] as String?) ?? 'request'} request',
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.childRequestButton,
                  disabledBackgroundColor: AppTheme.childRequestButton.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _selectedSymbol == null ? null : _sendRequest,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _selectedSymbol == null
                        ? 'Select a symbol to send request'
                        : 'Send "${(_selectedSymbol?['label'] as String?) ?? 'request'}"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppTheme.statusError, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text(
                'Retry',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyButton extends StatelessWidget {
  final String label;
  final String emoji;
  final VoidCallback onTap;

  const _EmergencyButton({
    required this.label,
    required this.emoji,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Emergency: $label',
      child: Material(
        color: AppTheme.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
