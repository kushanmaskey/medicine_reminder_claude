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

  factory AppointmentAlert.fromJson(Map<String, dynamic> json) =>
      AppointmentAlert(
        id: json['id'],
        appointmentId: json['appointmentId'],
        scheduledAt: DateTime.parse(json['scheduledAt']),
        acknowledged: json['acknowledged'] as bool? ?? false,
      );
}
