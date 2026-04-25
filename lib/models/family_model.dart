/// Represents a family unit in the system.
class FamilyModel {
  final String id;
  final String familyCode;
  final String? createdBy;
  final String? pinHash;
  final DateTime? createdAt;

  const FamilyModel({
    required this.id,
    required this.familyCode,
    this.createdBy,
    this.pinHash,
    this.createdAt,
  });

  factory FamilyModel.fromJson(Map<String, dynamic> json) {
    return FamilyModel(
      id: json['id'] as String,
      familyCode: json['family_code'] as String,
      createdBy: json['created_by'] as String?,
      pinHash: json['pin_hash'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'family_code': familyCode,
        'created_by': createdBy,
        'pin_hash': pinHash,
      };
}
