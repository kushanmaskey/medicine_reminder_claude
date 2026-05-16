import 'package:flutter/material.dart';
import '../models/appointment.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

class AppointmentsTab extends StatefulWidget {
  const AppointmentsTab({super.key});

  @override
  State<AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<AppointmentsTab> {
  List<Appointment> _appointments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await StorageService.getAppointments();
    list.sort((a, b) => a.appointmentDateTime.compareTo(b.appointmentDateTime));
    if (mounted) setState(() { _appointments = list; _loading = false; });
  }

  Future<void> _delete(Appointment a) async {
    await StorageService.deleteAppointment(a.id);
    await NotificationService.cancelNotification(
        NotificationService.idFromString(a.id));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No Appointments Yet',
                style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Tap + to add your first appointment',
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _appointments.length,
        itemBuilder: (ctx, i) {
          final a = _appointments[i];
          return _AppointmentCard(
            appointment: a,
            onDelete: () => _delete(a),
          );
        },
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onDelete;

  const _AppointmentCard({required this.appointment, required this.onDelete});

  String _daysLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final apptDay = DateTime(dt.year, dt.month, dt.day);
    final diff = apptDay.difference(today).inDays;
    if (diff < 0) return 'Past';
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return 'In $diff days';
  }

  Color _urgencyColor(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final apptDay = DateTime(dt.year, dt.month, dt.day);
    final diff = apptDay.difference(today).inDays;
    if (diff < 0) return Colors.grey.shade400;
    if (diff <= 1) return const Color(0xFFEF4444);
    if (diff <= 7) return const Color(0xFFF97316);
    return const Color(0xFF8B5CF6);
  }

  @override
  Widget build(BuildContext context) {
    final dt = appointment.appointmentDateTime;
    final isPast = dt.isBefore(DateTime.now());
    final urgencyColor = _urgencyColor(dt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPast ? Colors.grey.shade200 : urgencyColor.withValues(alpha: 0.3),
          width: isPast ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.calendar_month,
                      color: isPast ? Colors.grey : const Color(0xFF8B5CF6),
                      size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    appointment.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isPast
                          ? Colors.grey
                          : const Color(0xFF1E293B),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: urgencyColor.withValues(alpha: isPast ? 0.08 : 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _daysLabel(dt),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: urgencyColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                  onPressed: () => _confirmDelete(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.access_time_outlined,
              label: 'Date & Time',
              value: _formatDateTime(dt),
              valueColor: isPast ? null : urgencyColor,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.person_outlined,
              label: 'Doctor',
              value: appointment.doctorName,
            ),
            if (appointment.location.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: appointment.location,
              ),
            ],
            if (appointment.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.notes_outlined,
                label: 'Notes',
                value: appointment.notes,
              ),
            ],
            if (!isPast) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.notifications_active_outlined,
                label: 'Reminder',
                value: 'At appointment time',
                valueColor: const Color(0xFF8B5CF6),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour == 0
        ? 12
        : dt.hour > 12
            ? dt.hour - 12
            : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  •  $hour:$minute $period';
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Appointment'),
        content: Text('Remove "${appointment.title}"?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); onDelete(); },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.grey[400]),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13),
              children: [
                TextSpan(
                    text: '$label: ',
                    style: TextStyle(color: Colors.grey[500])),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: valueColor ?? const Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
