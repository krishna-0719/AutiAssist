/// Status of a request.
enum RequestStatus { pending, done }

/// A request from the child to the caregiver.
class RequestModel {
  final String id;
  final String? userId;
  final String type;
  final String? room;
  final RequestStatus status;
  final String familyId;
  final DateTime createdAt;

  const RequestModel({
    required this.id,
    this.userId,
    required this.type,
    this.room,
    this.status = RequestStatus.pending,
    required this.familyId,
    required this.createdAt,
  });

  factory RequestModel.fromJson(Map<String, dynamic> json) {
    return RequestModel(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      type: json['type'] as String,
      room: json['room'] as String?,
      status: (json['status'] as String?) == 'done'
          ? RequestStatus.done
          : RequestStatus.pending,
      familyId: json['family_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'room': room,
        'status': status == RequestStatus.done ? 'done' : 'pending',
        'family_id': familyId,
        'user_id': userId,
      };

  /// Human-readable time ago string.
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Emoji for the request type.
  String get emoji {
    const emojiMap = {
      'water': '💧', 'food': '🍽️', 'bathroom': '🚻', 'help': '🆘',
      'play': '🧸', 'sleep': '😴', 'music': '🎵', 'hug': '🤗',
      'outside': '🌳', 'pain': '🤕',
    };
    return emojiMap[type.toLowerCase()] ?? '✨';
  }

  RequestModel copyWith({RequestStatus? status}) {
    return RequestModel(
      id: id,
      userId: userId,
      type: type,
      room: room,
      status: status ?? this.status,
      familyId: familyId,
      createdAt: createdAt,
    );
  }
}
