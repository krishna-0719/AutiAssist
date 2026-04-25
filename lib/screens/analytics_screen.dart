import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';

import '../providers/analytics_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/caregiver_nav_bar.dart';

/// Analytics screen — charts, insights, and time range selectors.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _selectedRange = 1; // 0=Today, 1=Week, 2=Month, 3=All
  int? _touchedPieIndex;

  @override
  Widget build(BuildContext context) {
    final analytics = ref.watch(analyticsProvider);
    final media = MediaQuery.of(context);
    final isTablet = media.size.width >= AppTheme.tabletBreakpoint;
    final padding = isTablet ? AppTheme.screenPaddingTablet : AppTheme.screenPaddingMobile;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/dashboard');
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        bottomNavigationBar: const CaregiverNavBar(currentIndex: 2),
      body: SafeArea(
        child: analytics.isLoading
            ? const _AnalyticsShimmer()
            : analytics.errorMessage != null
                ? _AnalyticsError(
                    message: analytics.errorMessage!,
                    onRetry: () => ref.read(analyticsProvider.notifier).loadData(),
                  )
                : RefreshIndicator(
                    onRefresh: () => ref.read(analyticsProvider.notifier).loadData(),
                    color: AppTheme.caregiverPrimary,
                    child: ListView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: EdgeInsets.all(padding),
                      children: [
                        // ─── Header ────
                        Text(
                          'Analytics',
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ).animate().fadeIn(duration: 400.ms),

                        const SizedBox(height: 16),

                        // ─── Time Range Selector ────
                        _TimeRangeSelector(
                          selected: _selectedRange,
                          onChanged: (i) => setState(() => _selectedRange = i),
                        ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                        const SizedBox(height: AppTheme.sectionSpacing),

                        // ─── Daily Trend Chart ────
                        _buildDailyChart(analytics.dailyData)
                            .animate()
                            .fadeIn(delay: 200.ms, duration: 500.ms)
                            .slideY(begin: 0.1),

                        const SizedBox(height: 20),

                        // ─── Type Distribution ────
                        _buildTypeChart(analytics.typeData)
                            .animate()
                            .fadeIn(delay: 300.ms, duration: 500.ms)
                            .slideY(begin: 0.1),

                        const SizedBox(height: 20),

                        // ─── Room Distribution ────
                        _buildRoomChart(analytics.roomData)
                            .animate()
                            .fadeIn(delay: 400.ms, duration: 500.ms)
                            .slideY(begin: 0.1),

                        const SizedBox(height: 20),

                        // ─── Peak Hours ────
                        _buildHourChart(analytics.hourData)
                            .animate()
                            .fadeIn(delay: 500.ms, duration: 500.ms)
                            .slideY(begin: 0.1),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
      ),
      ),
    );
  }

  // ─── Daily Chart ──────────────────────────────────────────────

  Widget _buildDailyChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return _emptyChart('Daily Requests', Icons.timeline_rounded);

    final maxY = data
            .map((d) => (d['count'] as num?)?.toDouble() ?? 0)
            .reduce((a, b) => a > b ? a : b) +
        2;

    return _ChartCard(
      title: 'Daily Requests',
      icon: Icons.trending_up_rounded,
      iconColor: AppTheme.caregiverPrimary,
      child: SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final label = data[group.x.toInt()]['day_label'] as String? ?? '';
                  return BarTooltipItem(
                    '$label\n${rod.toY.toInt()} requests',
                    GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (val, _) {
                    final i = val.toInt();
                    if (i < 0 || i >= data.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        data[i]['day_label'] as String? ?? '',
                        style: const TextStyle(fontSize: 10, color: AppTheme.textMedium),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (value) => FlLine(
                color: AppTheme.cardBorder.withValues(alpha: 0.4),
                strokeWidth: 1,
              ),
            ),
            barGroups: List.generate(data.length, (i) {
              return BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: (data[i]['count'] as num?)?.toDouble() ?? 0,
                  gradient: const LinearGradient(
                    colors: [AppTheme.caregiverPrimary, Color(0xFF7986CB)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 22,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
              ]);
            }),
          ),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        ),
      ),
    );
  }

  // ─── Type Pie Chart ───────────────────────────────────────────

  Widget _buildTypeChart(Map<String, int> data) {
    if (data.isEmpty) return _emptyChart('Requests by Type', Icons.donut_large_rounded);

    const colors = [
      AppTheme.caregiverPrimary,
      AppTheme.caregiverAccent,
      AppTheme.secondary,
      AppTheme.caregiverWarning,
      AppTheme.orange,
      AppTheme.pink,
    ];
    final entries = data.entries.toList();
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);

    return _ChartCard(
      title: 'Requests by Type',
      icon: Icons.donut_large_rounded,
      iconColor: AppTheme.caregiverAccent,
      child: SizedBox(
        height: 200,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        _touchedPieIndex = response?.touchedSection?.touchedSectionIndex;
                      });
                    },
                  ),
                  sections: List.generate(entries.length, (i) {
                    final isTouched = _touchedPieIndex == i;
                    return PieChartSectionData(
                      value: entries[i].value.toDouble(),
                      title: isTouched ? '${entries[i].value}' : '',
                      color: colors[i % colors.length],
                      radius: isTouched ? 60 : 50,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }),
                  centerSpaceRadius: 35,
                  sectionsSpace: 3,
                ),
                duration: const Duration(milliseconds: 300),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(entries.length, (i) {
                    final pct = total > 0 ? (entries[i].value / total * 100).toInt() : 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: colors[i % colors.length],
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entries[i].key,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMedium),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '$pct%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Room Chart ───────────────────────────────────────────────

  Widget _buildRoomChart(Map<String, int> data) {
    if (data.isEmpty) return _emptyChart('Requests by Room', Icons.meeting_room_rounded);

    final entries = data.entries.toList();
    final maxVal = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    const barColors = [
      AppTheme.caregiverPrimary,
      AppTheme.accent,
      AppTheme.secondary,
      AppTheme.caregiverWarning,
      AppTheme.orange,
    ];

    return _ChartCard(
      title: 'Requests by Room',
      icon: Icons.meeting_room_rounded,
      iconColor: AppTheme.accent,
      child: Column(
        children: entries.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final fraction = maxVal > 0 ? e.value / maxVal : 0.0;
          final color = barColors[i % barColors.length];

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    e.key,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: fraction),
                      duration: Duration(milliseconds: 600 + (i * 100)),
                      curve: Curves.easeOutCubic,
                      builder: (_, value, __) => LinearProgressIndicator(
                        value: value,
                        backgroundColor: color.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${e.value}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppTheme.textDark,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Peak Hours Chart ─────────────────────────────────────────

  Widget _buildHourChart(Map<int, int> data) {
    if (data.isEmpty) return _emptyChart('Peak Hours', Icons.access_time_rounded);

    final maxY = data.values.reduce((a, b) => a > b ? a : b).toDouble() + 1;

    return _ChartCard(
      title: 'Peak Hours',
      icon: Icons.access_time_rounded,
      iconColor: AppTheme.secondary,
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '${group.x}:00\n${rod.toY.toInt()} requests',
                    GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (val, _) {
                    final h = val.toInt();
                    if (h % 4 != 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${h}h',
                        style: const TextStyle(fontSize: 10, color: AppTheme.textMedium),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / 3,
              getDrawingHorizontalLine: (value) => FlLine(
                color: AppTheme.cardBorder.withValues(alpha: 0.4),
                strokeWidth: 1,
              ),
            ),
            barGroups: data.entries.map((e) {
              return BarChartGroupData(x: e.key, barRods: [
                BarChartRodData(
                  toY: e.value.toDouble(),
                  gradient: const LinearGradient(
                    colors: [AppTheme.secondary, Color(0xFF26C6DA)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                ),
              ]);
            }).toList(),
          ),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        ),
      ),
    );
  }

  Widget _emptyChart(String title, IconData icon) {
    return _ChartCard(
      title: title,
      icon: icon,
      iconColor: AppTheme.textLight,
      child: SizedBox(
        height: 100,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32, color: AppTheme.textLight.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              const Text(
                'No data yet',
                style: TextStyle(color: AppTheme.textLight, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Time Range Selector ────────────────────────────────────────────

class _TimeRangeSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _TimeRangeSelector({required this.selected, required this.onChanged});

  static const _labels = ['Today', 'Week', 'Month', 'All'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final isActive = selected == i;
          return Semantics(
            button: true,
            label: 'Show ${_labels[i]} data',
            selected: isActive,
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.caregiverPrimary : AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? AppTheme.caregiverPrimary
                        : AppTheme.cardBorder.withValues(alpha: 0.5),
                  ),
                  boxShadow: isActive ? AppTheme.coloredShadow(AppTheme.caregiverPrimary) : null,
                ),
                child: Text(
                  _labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.white : AppTheme.textMedium,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Chart Card ─────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: AppTheme.cardBorder.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

// ─── Shimmer Loading ────────────────────────────────────────────────

class _AnalyticsShimmer extends StatelessWidget {
  const _AnalyticsShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.screenPaddingMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 160,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.shimmerBase,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: List.generate(
              4,
              (_) => Container(
                width: 70,
                height: 36,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppTheme.shimmerBase,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.sectionSpacing),
          ...List.generate(
            3,
            (_) => Container(
              height: 200,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.shimmerBase,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error State ────────────────────────────────────────────────────

class _AnalyticsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _AnalyticsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.analytics_outlined, size: 56, color: AppTheme.statusError),
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
