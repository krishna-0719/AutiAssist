/// Immutable snapshot of the child's detected room location.
class ChildLocation {
  final String room;
  final double confidence;
  final DateTime timestamp;
  final bool isOnline;

  const ChildLocation({
    required this.room,
    required this.confidence,
    required this.timestamp,
    this.isOnline = true,
  });

  factory ChildLocation.fromBroadcast(Map<String, dynamic> payload) {
    return ChildLocation(
      room: payload['room'] as String? ?? 'Unknown',
      confidence: (payload['confidence'] as num?)?.toDouble() ?? 0.0,
      timestamp: payload['timestamp'] != null
          ? DateTime.parse(payload['timestamp'] as String)
          : DateTime.now(),
      isOnline: true,
    );
  }

  /// Confidence as a human-readable label.
  String get confidenceLabel {
    if (confidence >= 0.75) return 'High';
    if (confidence >= 0.45) return 'Medium';
    return 'Low';
  }

  /// Confidence as an integer percentage.
  int get confidencePercent => (confidence * 100).toInt();

  /// Human-readable time since this location was reported.
  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 5) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
