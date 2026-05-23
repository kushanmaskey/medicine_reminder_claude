class PrescriptionAlert {
  final String id;
  final String prescriptionId;
  final DateTime scheduledAt;
  final bool acknowledged;

  const PrescriptionAlert({
    required this.id,
    required this.prescriptionId,
    required this.scheduledAt,
    this.acknowledged = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'prescriptionId': prescriptionId,
        'scheduledAt': scheduledAt.toIso8601String(),
        'acknowledged': acknowledged,
      };

  static DateTime _tryParse(dynamic value) {
    if (value == null) return DateTime.now();
    try {
      return DateTime.parse(value as String);
    } catch (_) {
      return DateTime.now();
    }
  }

  factory PrescriptionAlert.fromJson(Map<String, dynamic> json) =>
      PrescriptionAlert(
        id: json['id'],
        prescriptionId: json['prescriptionId'],
        scheduledAt: _tryParse(json['scheduledAt']),
        acknowledged: json['acknowledged'] as bool? ?? false,
      );
}
