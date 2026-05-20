import 'package:flutter/material.dart';
import '../models/appointment.dart';
import '../models/appointment_alert.dart';
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
    final active = list
        .where((a) => a.appointmentDateTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.appointmentDateTime.compareTo(b.appointmentDateTime));
    if (mounted) setState(() { _appointments = active; _loading = false; });
  }

  void reload() => _load();

  Future<void> _delete(Appointment a) async {
    await StorageService.deleteAppointment(a.id);
    await NotificationService.cancelNotification(
        NotificationService.idFromString(a.id));
    _load();
  }

  Future<void> _edit(Appointment a) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddAppointmentScreen(existing: a)),
    );
    if (result == true) _load();
  }

  Future<void> _acknowledge(AppointmentAlert alert) async {
    await StorageService.acknowledgeAlert(alert.id);
    await NotificationService.cancelNotification(
        NotificationService.idFromString(alert.id));
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
            Icon(Icons.calendar_today_outlined,
                size: 64, color: Colors.grey[300]),
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
            onEdit: () => _edit(a),
            onDelete: () => _delete(a),
            onAcknowledge: _acknowledge,
          );
        },
      ),
    );
  }
}

// ── Appointment Card ────────────────────────────────────────────────────────

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function(AppointmentAlert) onAcknowledge;

  const _AppointmentCard({
    required this.appointment,
    required this.onEdit,
    required this.onDelete,
    required this.onAcknowledge,
  });

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

  String _formatDateTime(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final hour = dt.hour == 0 ? 12 : dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  •  $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final dt = appointment.appointmentDateTime;
    final isPast = dt.isBefore(DateTime.now());
    final urgencyColor = _urgencyColor(dt);
    final activeAlerts = appointment.activeAlerts;
    final acknowledgedAlerts =
        appointment.alerts.where((a) => a.acknowledged).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPast
              ? Colors.grey.shade200
              : urgencyColor.withValues(alpha: 0.3),
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
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
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
                          color: isPast ? Colors.grey : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: urgencyColor
                            .withValues(alpha: isPast ? 0.08 : 0.12),
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
                      icon: const Icon(Icons.edit_outlined,
                          color: Color(0xFF8B5CF6), size: 20),
                      onPressed: onEdit,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Edit',
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 20),
                      onPressed: () => _confirmDelete(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Info rows
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

                // Alerts section
                if (appointment.alerts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.notifications_outlined,
                          size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 6),
                      Text(
                        'Alerts',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (activeAlerts.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${activeAlerts.length} active',
                            style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF8B5CF6),
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Active alerts with acknowledge button
                  ...activeAlerts.map((alert) => _ActiveAlertRow(
                        alert: alert,
                        formatDt: _formatDateTime,
                        onAcknowledge: () => onAcknowledge(alert),
                      )),

                  // Acknowledged alerts (collapsed summary)
                  if (acknowledgedAlerts.isNotEmpty) ...[
                    if (activeAlerts.isNotEmpty) const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 14, color: Colors.green),
                        const SizedBox(width: 6),
                        Text(
                          '${acknowledgedAlerts.length} acknowledged',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Appointment'),
        content: Text('Remove "${appointment.title}"?'),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Active alert row ─────────────────────────────────────────────────────────

class _ActiveAlertRow extends StatefulWidget {
  final AppointmentAlert alert;
  final String Function(DateTime) formatDt;
  final Future<void> Function() onAcknowledge;

  const _ActiveAlertRow({
    required this.alert,
    required this.formatDt,
    required this.onAcknowledge,
  });

  @override
  State<_ActiveAlertRow> createState() => _ActiveAlertRowState();
}

class _ActiveAlertRowState extends State<_ActiveAlertRow> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.alarm_outlined,
              size: 16, color: Color(0xFF8B5CF6)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.formatDt(widget.alert.scheduledAt),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E293B)),
            ),
          ),
          _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF8B5CF6)),
                )
              : GestureDetector(
                  onTap: () async {
                    setState(() => _loading = true);
                    await widget.onAcknowledge();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// ── Info row ─────────────────────────────────────────────────────────────────

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
