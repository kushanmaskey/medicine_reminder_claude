import 'package:flutter/material.dart';
import '../models/appointment.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../screens/add_appointment_screen.dart';

class AppointmentsTab extends StatefulWidget {
  const AppointmentsTab({super.key});

  @override
  State<AppointmentsTab> createState() => AppointmentsTabState();
}

class AppointmentsTabState extends State<AppointmentsTab> {
  List<Appointment> _appointments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await StorageService.getAppointments();
    final now = DateTime.now();

    for (final a in list.where((a) => !a.appointmentDateTime.isAfter(now))) {
      await StorageService.deleteAppointment(a.id);
      await NotificationService.cancelNotification(
          NotificationService.idFromString(a.id));
    }

    final active = list
        .where((a) => a.appointmentDateTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.appointmentDateTime.compareTo(b.appointmentDateTime));
    if (mounted) setState(() { _appointments = active; _loading = false; });
  }

  void reload() => _load();

  Future<void> _open(Appointment a) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => AddAppointmentScreen(existing: a)),
    );
    if (result == true || result == 'deleted') _load();
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
            Icon(Icons.calendar_today_outlined,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No Upcoming Appointments',
                style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Tap + to schedule an appointment',
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
        itemBuilder: (ctx, i) => _AppointmentCard(
          appointment: _appointments[i],
          onTap: () => _open(_appointments[i]),
        ),
      ),
    );
  }
}

// ── Compact appointment card ──────────────────────────────────────────────────

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onTap;

  const _AppointmentCard({required this.appointment, required this.onTap});

  Color _urgencyColor(DateTime dt) {
    final diff = DateTime(dt.year, dt.month, dt.day)
        .difference(DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day))
        .inDays;
    if (diff <= 1) return const Color(0xFFEF4444);
    if (diff <= 7) return const Color(0xFFF97316);
    return const Color(0xFF8B5CF6);
  }

  String _daysLabel(DateTime dt) {
    final diff = DateTime(dt.year, dt.month, dt.day)
        .difference(DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return 'In $diff days';
  }

  String _formatDateTime(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final hour = dt.hour == 0 ? 12 : dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  •  $hour:$min $period';
  }

  @override
  Widget build(BuildContext context) {
    final dt = appointment.appointmentDateTime;
    final color = _urgencyColor(dt);
    final activeAlertCount = appointment.activeAlerts.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.calendar_month, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Appt with ${appointment.doctorName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatDateTime(dt),
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _daysLabel(dt),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color),
                      ),
                    ),
                    if (activeAlertCount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.notifications_active_outlined,
                              size: 11,
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.7)),
                          const SizedBox(width: 2),
                          Text(
                            '$activeAlertCount',
                            style: TextStyle(
                                fontSize: 10,
                                color: const Color(0xFF8B5CF6)
                                    .withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
