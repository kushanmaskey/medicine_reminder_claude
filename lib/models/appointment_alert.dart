class AppointmentAlert {
  final String id;
  final String appointmentId;
  final DateTime scheduledAt;
  final bool acknowledged;

  const AppointmentAlert({
    required this.id,
    required this.appointmentId,
    required this.scheduledAt,
    this.acknowledged = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'appointmentId': appointmentId,
        'scheduledAt': scheduledAt.toIso8601String(),
        'acknowledged': acknowledged,
      };

  static DateTime _tryParse(dynamic value) {
    if (value == null) return DateTime.now();
    try { return DateTime.parse(value as String); } catch (_) { return DateTime.now(); }
  }

  factory AppointmentAlert.fromJson(Map<String, dynamic> json) =>
      AppointmentAlert(
        id: json['id'],
        appointmentId: json['appointmentId'],
        scheduledAt: _tryParse(json['scheduledAt']),
        acknowledged: json['acknowledged'] as bool? ?? false,
      );
}
