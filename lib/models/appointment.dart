class Appointment {
  final String id;
  final String title;
  final String doctorName;
  final String location;
  final String notes;
  final DateTime appointmentDateTime;

  Appointment({
    required this.id,
    required this.title,
    required this.doctorName,
    required this.location,
    required this.notes,
    required this.appointmentDateTime,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'doctorName': doctorName,
        'location': location,
        'notes': notes,
        'appointmentDateTime': appointmentDateTime.toIso8601String(),
      };

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: json['id'],
        title: json['title'],
        doctorName: json['doctorName'],
        location: json['location'],
        notes: json['notes'],
        appointmentDateTime: DateTime.parse(json['appointmentDateTime']),
      );
}
