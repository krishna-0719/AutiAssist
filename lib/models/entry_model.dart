/// A caregiver diary/journal entry.
class EntryModel {
  final String id;
  final String familyId;
  final String? userId;
  final String title;
  final String? description;
  final DateTime createdAt;

  const EntryModel({
    required this.id,
    required this.familyId,
    this.userId,
    required this.title,
    this.description,
    required this.createdAt,
  });

  factory EntryModel.fromJson(Map<String, dynamic> json) {
    return EntryModel(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      userId: json['user_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'family_id': familyId,
        'user_id': userId,
        'title': title,
        'description': description,
      };

  /// Human-readable date string.
  String get dateLabel {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}
