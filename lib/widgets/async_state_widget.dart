import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

/// Reusable widget that handles loading, error, and data states.
class AsyncStateWidget<T> extends StatelessWidget {
  final AsyncSnapshot<T>? snapshot;
  final bool? isLoading;
  final String? errorMessage;
  final T? data;
  final Widget Function(T data) builder;
  final Widget? emptyWidget;
  final int shimmerCount;

  const AsyncStateWidget({
    super.key,
    this.snapshot,
    this.isLoading,
    this.errorMessage,
    this.data,
    required this.builder,
    this.emptyWidget,
    this.shimmerCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (isLoading == true || (snapshot != null && snapshot!.connectionState == ConnectionState.waiting)) {
      return _buildShimmer();
    }

    // Error state
    final error = errorMessage ?? (snapshot?.hasError == true ? '${snapshot!.error}' : null);
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.danger),
              const SizedBox(height: 16),
              Text(error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textMedium, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    // Data state
    final resolvedData = data ?? snapshot?.data;
    if (resolvedData == null) {
      return emptyWidget ?? const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_rounded, size: 48, color: AppTheme.textLight),
              SizedBox(height: 16),
              Text('No data yet',
                  style: TextStyle(color: AppTheme.textLight, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return builder(resolvedData);
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: shimmerCount,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
