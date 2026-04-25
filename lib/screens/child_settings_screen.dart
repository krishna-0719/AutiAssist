import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Child settings screen (PIN-locked) — accessed from child device.
class ChildSettingsScreen extends StatelessWidget {
  const ChildSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text('Child Settings', style: GoogleFonts.outfit(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SettingsTile(
            icon: Icons.wifi_find_rounded,
            color: AppTheme.accent,
            title: 'Room Calibration',
            subtitle: 'Calibrate WiFi fingerprints for each room',
            onTap: () => context.push('/room-calibration'),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.room_rounded,
            color: AppTheme.success,
            title: 'Manage Rooms',
            subtitle: 'Add or remove rooms',
            onTap: () => context.push('/manage-rooms'),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon, required this.color, required this.title,
    required this.subtitle, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surface, borderRadius: AppTheme.cardRadius, boxShadow: AppTheme.softShadow),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textMedium)),
              ],
            )),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.textLight),
          ],
        ),
      ),
    );
  }
}
