class Activity {
  final String id;
  final String type; // Walk | Run | Exercise | Yoga | Meditation
  final String walkType; // Brisk | Regular (Walk only)
  final double? distance; // miles (Walk, Run)
  final double? duration; // minutes (Exercise, Yoga, Meditation)
  final DateTime recordedAt;
  final String notes;

  Activity({
    required this.id,
    required this.type,
    this.walkType = 'Regular',
    this.distance,
    this.duration,
    required this.recordedAt,
    this.notes = '',
  });

  bool get isDistanceBased => type == 'Walk' || type == 'Run';

  String get displayValue {
    if (isDistanceBased) {
      return distance != null ? '${distance!.toStringAsFixed(1)} mi' : '—';
    }
    return duration != null ? '${duration!.toStringAsFixed(0)} min' : '—';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'walkType': walkType,
        'distance': distance,
        'duration': duration,
        'recordedAt': recordedAt.toIso8601String(),
        'notes': notes,
      };

  static DateTime _tryParse(dynamic value) {
    if (value == null) return DateTime.now();
    try { return DateTime.parse(value as String); } catch (_) { return DateTime.now(); }
  }

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        id: json['id'] as String,
        type: json['type'] as String,
        walkType: (json['walkType'] as String?) ?? 'Regular',
        distance: (json['distance'] as num?)?.toDouble(),
        duration: (json['duration'] as num?)?.toDouble(),
        recordedAt: _tryParse(json['recordedAt']),
        notes: (json['notes'] as String?) ?? '',
      );
}
