/// A room registered by the caregiver.
class RoomModel {
  final String id;
  final String familyId;
  final String name;
  final DateTime? createdAt;

  const RoomModel({
    required this.id,
    required this.familyId,
    required this.name,
    this.createdAt,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      name: json['name'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'family_id': familyId,
        'name': name,
      };
}
