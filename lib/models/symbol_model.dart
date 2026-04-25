/// A symbol displayed on the child's AAC board.
class SymbolModel {
  final String? id;
  final String? familyId;
  final String type;
  final String label;
  final String? emoji;
  final String? color;
  final String? roomName;
  final String? imageUrl;
  final DateTime? createdAt;

  const SymbolModel({
    this.id,
    this.familyId,
    required this.type,
    required this.label,
    this.emoji,
    this.color,
    this.roomName,
    this.imageUrl,
    this.createdAt,
  });

  factory SymbolModel.fromJson(Map<String, dynamic> json) {
    return SymbolModel(
      id: json['id'] as String?,
      familyId: json['family_id'] as String?,
      type: json['type'] as String,
      label: json['label'] as String,
      emoji: json['emoji'] as String?,
      color: json['color'] as String?,
      roomName: json['room_name'] as String?,
      imageUrl: json['image_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'family_id': familyId,
        'type': type,
        'label': label,
        'emoji': emoji,
        'color': color,
        'room_name': roomName,
        'image_url': imageUrl,
      };

  /// Convert to the `Map<String, dynamic>` format used by providers/widgets.
  Map<String, dynamic> toMap() => {
        'id': id,
        'family_id': familyId,
        'type': type,
        'label': label,
        'emoji': emoji ?? '✨',
        'color': color,
        'room_name': roomName,
        'image_url': imageUrl,
      };

  SymbolModel copyWith({
    String? label,
    String? emoji,
    String? color,
    String? roomName,
    String? imageUrl,
  }) {
    return SymbolModel(
      id: id,
      familyId: familyId,
      type: type,
      label: label ?? this.label,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      roomName: roomName ?? this.roomName,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt,
    );
  }
}
