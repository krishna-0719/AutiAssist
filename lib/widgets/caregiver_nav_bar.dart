import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Premium bottom navigation bar for caregiver screens — 5 destinations.
class CaregiverNavBar extends StatelessWidget {
  final int currentIndex;

  const CaregiverNavBar({
    super.key,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Caregiver navigation',
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            height: 72,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            indicatorColor: AppTheme.caregiverPrimary.withValues(alpha: 0.12),
            selectedIndex: currentIndex.clamp(0, 4),
            onDestinationSelected: (index) => _onTap(context, index),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined, size: 24),
                selectedIcon: Icon(Icons.dashboard_rounded, size: 24,
                    color: AppTheme.caregiverPrimary),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_none_rounded, size: 24),
                selectedIcon: Icon(Icons.notifications_active_rounded, size: 24,
                    color: AppTheme.caregiverPrimary),
                label: 'Requests',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined, size: 24),
                selectedIcon: Icon(Icons.bar_chart_rounded, size: 24,
                    color: AppTheme.caregiverPrimary),
                label: 'Analytics',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined, size: 24),
                selectedIcon: Icon(Icons.grid_view_rounded, size: 24,
                    color: AppTheme.caregiverPrimary),
                label: 'Symbols',
              ),
              NavigationDestination(
                icon: Icon(Icons.more_horiz_rounded, size: 24),
                selectedIcon: Icon(Icons.more_horiz_rounded, size: 24,
                    color: AppTheme.caregiverPrimary),
                label: 'More',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
      case 1:
        context.go('/requests');
      case 2:
        context.go('/analytics');
      case 3:
        context.go('/manage-symbols');
      case 4:
        _showMoreSheet(context);
    }
  }

  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppTheme.sheetRadius),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _MoreTile(
                icon: Icons.meeting_room_rounded,
                label: 'Manage Rooms',
                color: AppTheme.secondary,
                onTap: () { Navigator.pop(ctx); context.push('/manage-rooms'); },
              ),
              _MoreTile(
                icon: Icons.location_searching_rounded,
                label: 'Find My Child',
                color: AppTheme.caregiverPing,
                onTap: () { Navigator.pop(ctx); context.push('/find-child'); },
              ),
              _MoreTile(
                icon: Icons.book_rounded,
                label: 'Diary',
                color: AppTheme.orange,
                onTap: () { Navigator.pop(ctx); context.push('/diary'); },
              ),
              _MoreTile(
                icon: Icons.wifi_find_rounded,
                label: 'Room Calibration',
                color: AppTheme.accent,
                onTap: () { Navigator.pop(ctx); context.push('/caregiver-room-calibration'); },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MoreTile({required this.icon, required this.label, required this.color, required this.onTap});

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
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textLight),
      onTap: onTap,
    );
  }
}
