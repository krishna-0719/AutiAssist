import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../models/request_model.dart';
import '../providers/dashboard_provider.dart';
import '../providers/service_providers.dart';
import '../providers/session_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/caregiver_nav_bar.dart';

/// Caregiver dashboard — hero stats, recent requests, quick actions.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final familyId = ref.watch(familyIdProvider);
    final media = MediaQuery.of(context);
    final isTablet = media.size.width >= AppTheme.tabletBreakpoint;
    final padding = isTablet ? AppTheme.screenPaddingTablet : AppTheme.screenPaddingMobile;

    return Scaffold(
      backgroundColor: AppTheme.background,
      bottomNavigationBar: const CaregiverNavBar(currentIndex: 0),
      floatingActionButton: FloatingActionButton(
        heroTag: 'dashboard_fab',
        onPressed: () => _showQuickActions(context),
        backgroundColor: AppTheme.caregiverPrimary,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
      body: SafeArea(
        child: dashboard.isLoading
            ? const _DashboardShimmer()
            : dashboard.errorMessage != null
                ? _DashboardError(
                    message: dashboard.errorMessage!,
                    onRetry: () => ref.read(dashboardProvider.notifier).loadData(),
                  )
                : RefreshIndicator(
                    onRefresh: () => ref.read(dashboardProvider.notifier).loadData(),
                    color: AppTheme.caregiverPrimary,
                    child: ListView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: EdgeInsets.all(padding),
                      children: [
                        // ─── Header ────
                        _DashboardHeader(familyCode: dashboard.familyCode),
                        const SizedBox(height: AppTheme.sectionSpacing),

                        // ─── Stats Grid ────
                        _StatsGrid(
                          isTablet: isTablet,
                          todayCount: dashboard.todayCount,
                          pendingCount: dashboard.pendingCount,
                          entryCount: dashboard.entryCount,
                        ),
                        const SizedBox(height: AppTheme.sectionSpacing),

                        // ─── Quick Nav Chips ────
                        _QuickNavChips(),
                        const SizedBox(height: AppTheme.sectionSpacing),

                        // ─── Recent Requests ────
                        if (familyId != null)
                          _RecentRequestsSection(familyId: familyId),
                      ],
                    ),
                  ),
      ),
    );
  }

  void _showQuickActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppTheme.sheetRadius),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.screenPaddingMobile),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 20),
              Text(
                'Quick Actions',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              _QuickActionTile(
                icon: Icons.grid_view_rounded,
                label: 'Manage Symbols',
                color: AppTheme.caregiverPrimary,
                onTap: () {
                  Navigator.pop(context);
                  context.push('/manage-symbols');
                },
              ),
              _QuickActionTile(
                icon: Icons.meeting_room_rounded,
                label: 'Manage Rooms',
                color: AppTheme.secondary,
                onTap: () {
                  Navigator.pop(context);
                  context.push('/manage-rooms');
                },
              ),
              _QuickActionTile(
                icon: Icons.location_searching_rounded,
                label: 'Find My Child',
                color: AppTheme.caregiverPing,
                onTap: () {
                  Navigator.pop(context);
                  context.push('/find-child');
                },
              ),
              _QuickActionTile(
                icon: Icons.book_rounded,
                label: 'Diary',
                color: AppTheme.orange,
                onTap: () {
                  Navigator.pop(context);
                  context.push('/diary');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  final String? familyCode;
  const _DashboardHeader({this.familyCode});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (familyCode != null)
                Text(
                  'Family: $familyCode',
                  style: const TextStyle(fontSize: 14, color: AppTheme.textMedium),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'Sign out',
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppTheme.softShadow,
            ),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: AppTheme.textMedium),
              onPressed: () => _confirmSignOut(context),
              tooltip: 'Sign out',
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  void _confirmSignOut(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.cardRadius),
        title: const Text('Sign Out?'),
        content: const Text('You will need to sign in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          Consumer(
            builder: (context, ref, _) => ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(sessionProvider.notifier).clearSession();
                context.go('/role-select');
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              child: const Text('Sign Out'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats Grid ─────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final bool isTablet;
  final int todayCount;
  final int pendingCount;
  final int entryCount;

  const _StatsGrid({
    required this.isTablet,
    required this.todayCount,
    required this.pendingCount,
    required this.entryCount,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatCardData(
        icon: Icons.today_rounded,
        label: 'Requests Today',
        value: todayCount,
        color: AppTheme.caregiverPrimary,
      ),
      _StatCardData(
        icon: Icons.pending_actions_rounded,
        label: 'Pending',
        value: pendingCount,
        color: AppTheme.caregiverWarning,
      ),
      _StatCardData(
        icon: Icons.book_rounded,
        label: 'Diary Entries',
        value: entryCount,
        color: AppTheme.secondary,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const crossAxisCount = 3;
        const spacing = 12.0;
        final cardWidth = (constraints.maxWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards.asMap().entries.map((entry) {
            return SizedBox(
              width: cardWidth,
              child: _StatCard(data: entry.value)
                  .animate()
                  .fadeIn(delay: (100 * entry.key).ms, duration: 400.ms)
                  .slideY(begin: 0.15, curve: Curves.easeOut),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StatCardData {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  const _StatCardData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${data.label}: ${data.value}',
      child: Container(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.softShadow,
          border: Border.all(color: AppTheme.cardBorder.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(data.icon, color: data.color, size: 22),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${data.value}',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textDark,
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              data.label,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMedium),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick Nav Chips ────────────────────────────────────────────────

class _QuickNavChips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      const _NavChipData(Icons.notifications_active_rounded, 'Requests', '/requests', AppTheme.caregiverAccent),
      const _NavChipData(Icons.bar_chart_rounded, 'Analytics', '/analytics', AppTheme.caregiverPrimary),
      const _NavChipData(Icons.location_searching_rounded, 'Find Child', '/find-child', AppTheme.caregiverPing),
      const _NavChipData(Icons.book_rounded, 'Diary', '/diary', AppTheme.orange),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final item = items[i];
          return Semantics(
            button: true,
            label: 'Navigate to ${item.label}',
            child: ActionChip(
              avatar: Icon(item.icon, size: 18, color: item.color),
              label: Text(
                item.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: item.color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: item.color.withValues(alpha: 0.3)),
              ),
              backgroundColor: item.color.withValues(alpha: 0.08),
              onPressed: () => context.push(item.route),
            ),
          );
        },
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms);
  }
}

class _NavChipData {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  const _NavChipData(this.icon, this.label, this.route, this.color);
}

// ─── Recent Requests ────────────────────────────────────────────────

class _RecentRequestsSection extends ConsumerWidget {
  final String familyId;
  const _RecentRequestsSection({required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestRepo = ref.watch(requestRepositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent Requests',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/requests'),
              child: const Text(
                'View All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.caregiverPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: requestRepo.streamRequests(familyId: familyId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppTheme.caregiverPrimary),
                ),
              );
            }

            final cutoff = DateTime.now().subtract(const Duration(hours: 24));
            final requests = snapshot.data!
                .map((e) => RequestModel.fromJson(e))
                .where((r) => r.createdAt.isAfter(cutoff))
                .take(5)
                .toList();

            if (requests.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.cardBorder.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inbox_rounded, size: 48, color: AppTheme.textLight.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text(
                      'No requests in the last 24 hours',
                      style: TextStyle(color: AppTheme.textLight, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: requests.asMap().entries.map((entry) {
                final req = entry.value;
                return _RecentRequestCard(request: req)
                    .animate()
                    .fadeIn(delay: (80 * entry.key).ms, duration: 300.ms)
                    .slideX(begin: 0.05, curve: Curves.easeOut);
              }).toList(),
            );
          },
        ),
      ],
    ).animate().fadeIn(delay: 400.ms, duration: 400.ms);
  }
}

class _RecentRequestCard extends StatelessWidget {
  final RequestModel request;
  const _RecentRequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final isDone = request.status == RequestStatus.done;

    return Semantics(
      label: '${request.type} request, ${isDone ? 'completed' : 'pending'}, ${request.timeAgo}',
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
            // Timeline indicator
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: isDone ? AppTheme.statusDone : AppTheme.statusPending,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            // Emoji
            Text(request.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.type,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${request.room ?? 'Unknown'} • ${request.timeAgo}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMedium),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDone
                    ? AppTheme.statusDone.withValues(alpha: 0.12)
                    : AppTheme.statusPending.withValues(alpha: 0.12),
                borderRadius: AppTheme.pillRadius,
              ),
              child: Text(
                isDone ? 'Done' : 'Pending',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDone ? AppTheme.statusDone : AppTheme.statusPending,
                ),
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

// ─── Quick Action Tile ──────────────────────────────────────────────

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textLight),
      onTap: onTap,
    );
  }
}

// ─── Shimmer Loading ────────────────────────────────────────────────

class _DashboardShimmer extends StatelessWidget {
  const _DashboardShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.screenPaddingMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header shimmer
          Container(
            width: 180,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.shimmerBase,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 120,
            height: 16,
            decoration: BoxDecoration(
              color: AppTheme.shimmerBase,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: AppTheme.sectionSpacing),
          // Stats shimmer
          Row(
            children: List.generate(
              3,
              (_) => Expanded(
                child: Container(
                  height: 120,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.shimmerBase,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.sectionSpacing),
          // Request cards shimmer
          ...List.generate(
            3,
            (_) => Container(
              height: 72,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppTheme.shimmerBase,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error State ────────────────────────────────────────────────────

class _DashboardError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _DashboardError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56, color: AppTheme.statusError),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, color: AppTheme.textMedium),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.caregiverPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
