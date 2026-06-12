class Allergy {
  final String id;
  final String name;
  final String? reason;
  final String? notes;

  Allergy({
    required this.id,
    required this.name,
    this.reason,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (reason != null) 'reason': reason,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };

  factory Allergy.fromJson(Map<String, dynamic> json) => Allergy(
        id: json['id'] as String,
        name: json['name'] as String,
        reason: json['reason'] as String?,
        notes: json['notes'] as String?,
      );
}
