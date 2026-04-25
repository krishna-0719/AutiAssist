import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../models/request_model.dart';
import '../providers/service_providers.dart';
import '../providers/session_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/caregiver_nav_bar.dart';

/// Request queue management — tabbed Pending / Completed with swipe actions.
class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({super.key});

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _updatingIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final familyId = ref.watch(familyIdProvider);
    final media = MediaQuery.of(context);
    final isTablet = media.size.width >= AppTheme.tabletBreakpoint;
    final padding = isTablet ? AppTheme.screenPaddingTablet : AppTheme.screenPaddingMobile;

    if (familyId == null) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: Text('Not logged in')),
      );
    }

    final requestRepo = ref.watch(requestRepositoryProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/dashboard');
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        bottomNavigationBar: const CaregiverNavBar(currentIndex: 1),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ────
            Padding(
              padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
              child: Text(
                'Requests',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 16),

            // ─── Tab Bar ────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.shimmerBase.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: AppTheme.caregiverPrimary,
                  unselectedLabelColor: AppTheme.textMedium,
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(text: '⏳ Pending'),
                    Tab(text: '✅ Completed'),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 150.ms, duration: 400.ms),

            const SizedBox(height: 16),

            // ─── Tab Content ────
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: requestRepo.streamRequests(familyId: familyId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.caregiverPrimary,
                      ),
                    );
                  }

                  final cutoff = DateTime.now().subtract(const Duration(hours: 24));
                  final allRequests = snapshot.data!
                      .map((e) => RequestModel.fromJson(e))
                      .where((r) => r.createdAt.isAfter(cutoff))
                      .toList();

                  final pending = allRequests
                      .where((r) => r.status == RequestStatus.pending)
                      .toList();
                  final completed = allRequests
                      .where((r) => r.status == RequestStatus.done)
                      .toList();

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _RequestList(
                        requests: pending,
                        emptyIcon: Icons.pending_actions_rounded,
                        emptyMessage: 'No pending requests',
                        emptySubMessage: 'All caught up! 🎉',
                        padding: padding,
                        updatingIds: _updatingIds,
                        onToggleStatus: (req) => _toggleStatus(req, requestRepo),
                        onDelete: (req) => _deleteRequest(req, requestRepo),
                        swipeDirection: DismissDirection.startToEnd,
                        swipeLabel: 'Mark Done',
                        swipeColor: AppTheme.statusDone,
                        swipeIcon: Icons.check_circle_rounded,
                      ),
                      _RequestList(
                        requests: completed,
                        emptyIcon: Icons.task_alt_rounded,
                        emptyMessage: 'No completed requests',
                        emptySubMessage: 'Completed requests appear here',
                        padding: padding,
                        updatingIds: _updatingIds,
                        onToggleStatus: (req) => _toggleStatus(req, requestRepo),
                        onDelete: (req) => _deleteRequest(req, requestRepo),
                        swipeDirection: DismissDirection.endToStart,
                        swipeLabel: 'Delete',
                        swipeColor: AppTheme.danger,
                        swipeIcon: Icons.delete_rounded,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _toggleStatus(RequestModel req, dynamic requestRepo) async {
    if (_updatingIds.contains(req.id)) return;
    setState(() => _updatingIds.add(req.id));
    HapticFeedback.lightImpact();

    try {
      final newStatus = req.status == RequestStatus.pending ? 'done' : 'pending';
      await requestRepo.updateStatus(requestId: req.id, status: newStatus);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'done' ? 'Marked as done ✅' : 'Moved back to pending',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                final undoStatus = newStatus == 'done' ? 'pending' : 'done';
                await requestRepo.updateStatus(requestId: req.id, status: undoStatus);
              },
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppTheme.chipRadius),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e', maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingIds.remove(req.id));
    }
  }

  Future<void> _deleteRequest(RequestModel req, dynamic requestRepo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.cardRadius),
        title: const Text('Delete Request'),
        content: Text(
          'Delete "${req.type}" request?',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await requestRepo.deleteRequest(req.id);
    }
  }
}

// ─── Request List ───────────────────────────────────────────────────

class _RequestList extends StatelessWidget {
  final List<RequestModel> requests;
  final IconData emptyIcon;
  final String emptyMessage;
  final String emptySubMessage;
  final double padding;
  final Set<String> updatingIds;
  final Function(RequestModel) onToggleStatus;
  final Function(RequestModel) onDelete;
  final DismissDirection swipeDirection;
  final String swipeLabel;
  final Color swipeColor;
  final IconData swipeIcon;

  const _RequestList({
    required this.requests,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.emptySubMessage,
    required this.padding,
    required this.updatingIds,
    required this.onToggleStatus,
    required this.onDelete,
    required this.swipeDirection,
    required this.swipeLabel,
    required this.swipeColor,
    required this.swipeIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return _EmptyRequestState(
        icon: emptyIcon,
        message: emptyMessage,
        subMessage: emptySubMessage,
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.fromLTRB(padding, 0, padding, 24),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        return _RequestCard(
          request: req,
          index: index,
          isUpdating: updatingIds.contains(req.id),
          onToggleStatus: () => onToggleStatus(req),
          onDelete: () => onDelete(req),
          swipeDirection: swipeDirection,
          swipeLabel: swipeLabel,
          swipeColor: swipeColor,
          swipeIcon: swipeIcon,
        );
      },
    );
  }
}

// ─── Request Card ───────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final RequestModel request;
  final int index;
  final bool isUpdating;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;
  final DismissDirection swipeDirection;
  final String swipeLabel;
  final Color swipeColor;
  final IconData swipeIcon;

  const _RequestCard({
    required this.request,
    required this.index,
    required this.isUpdating,
    required this.onToggleStatus,
    required this.onDelete,
    required this.swipeDirection,
    required this.swipeLabel,
    required this.swipeColor,
    required this.swipeIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = request.status == RequestStatus.done;

    return Dismissible(
      key: Key(request.id),
      direction: swipeDirection,
      background: Container(
        alignment: swipeDirection == DismissDirection.startToEnd
            ? Alignment.centerLeft
            : Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.only(
          left: swipeDirection == DismissDirection.startToEnd ? 24 : 0,
          right: swipeDirection == DismissDirection.endToStart ? 24 : 0,
        ),
        decoration: BoxDecoration(
          color: swipeColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (swipeDirection == DismissDirection.endToStart) ...[
              Text(
                swipeLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: swipeColor,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(swipeIcon, color: swipeColor, size: 24),
            if (swipeDirection == DismissDirection.startToEnd) ...[
              const SizedBox(width: 8),
              Text(
                swipeLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: swipeColor,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
      confirmDismiss: (_) async {
        if (isDone && swipeDirection == DismissDirection.endToStart) {
          onDelete();
          return false;
        }
        onToggleStatus();
        return false;
      },
      child: Semantics(
        label: '${request.type} request from ${request.room ?? 'unknown room'}, '
            '${isDone ? 'completed' : 'pending'}, ${request.timeAgo}',
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.softShadow,
            border: Border.all(color: AppTheme.cardBorder.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              // Emoji
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (isDone ? AppTheme.statusDone : AppTheme.statusPending)
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(request.emoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.type,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppTheme.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${request.room ?? 'Unknown'} • ${request.timeAgo}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMedium),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Action button
              GestureDetector(
                onTap: isUpdating ? null : onToggleStatus,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDone
                        ? AppTheme.statusDone.withValues(alpha: 0.12)
                        : AppTheme.statusPending.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: isUpdating
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              isDone ? AppTheme.statusDone : AppTheme.statusPending,
                            ),
                          ),
                        )
                      : Text(
                          isDone ? '✅ Done' : '⏳ Mark Done',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: isDone ? AppTheme.statusDone : AppTheme.statusPending,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (60 * index).ms, duration: 300.ms).slideX(begin: 0.05);
  }
}

// ─── Empty State ────────────────────────────────────────────────────

class _EmptyRequestState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subMessage;

  const _EmptyRequestState({
    required this.icon,
    required this.message,
    required this.subMessage,
  });

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
              child: Icon(icon, size: 48, color: AppTheme.textLight),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMedium,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subMessage,
              style: const TextStyle(fontSize: 14, color: AppTheme.textLight),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).scale(
          begin: const Offset(0.9, 0.9),
          curve: Curves.easeOutBack,
        );
  }
}
