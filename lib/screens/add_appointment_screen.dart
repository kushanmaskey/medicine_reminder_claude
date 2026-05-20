import 'package:flutter/material.dart';
import '../models/appointment.dart';
import '../models/appointment_alert.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

class AddAppointmentScreen extends StatefulWidget {
  final Appointment? existing;
  const AddAppointmentScreen({super.key, this.existing});

  @override
  State<AddAppointmentScreen> createState() => _AddAppointmentScreenState();
}

class _AddAppointmentScreenState extends State<AddAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _doctorController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _appointmentDate;
  TimeOfDay? _appointmentTime;

  // Alert state
  final List<DateTime> _newAlerts = [];
  final Set<String> _removedAlertIds = {};

  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  static const _purple = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.existing!;
      _titleController.text = e.title;
      _doctorController.text = e.doctorName;
      _locationController.text = e.location;
      _notesController.text = e.notes;
      _appointmentDate = e.appointmentDateTime;
      _appointmentTime = TimeOfDay.fromDateTime(e.appointmentDateTime);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _doctorController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _appointmentDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _purple),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _appointmentDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _appointmentTime ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _purple),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _appointmentTime = picked);
  }

  Future<void> _addAlert() async {
    final defaultDate = _appointmentDate ?? DateTime.now().add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: defaultDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _purple),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _appointmentTime ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _purple),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (dt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert time must be in the future')),
      );
      return;
    }
    setState(() => _newAlerts.add(dt));
  }

  String _formatDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hour == 0 ? 12 : t.hour > 12 ? t.hour - 12 : t.hour;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatAlertDt(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final hour = dt.hour == 0 ? 12 : dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  •  $hour:$minute $period';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_appointmentDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an appointment date')),
      );
      return;
    }
    if (_appointmentTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an appointment time')),
      );
      return;
    }
    setState(() => _saving = true);

    final dt = DateTime(
      _appointmentDate!.year, _appointmentDate!.month, _appointmentDate!.day,
      _appointmentTime!.hour, _appointmentTime!.minute,
    );

    final appointment = Appointment(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      doctorName: _doctorController.text.trim(),
      location: _locationController.text.trim(),
      notes: _notesController.text.trim(),
      appointmentDateTime: dt,
    );

    // Cancel existing single notification
    await NotificationService.cancelNotification(
        NotificationService.idFromString(appointment.id));

    if (_isEditing) {
      await StorageService.updateAppointment(appointment);
      // Delete removed alerts
      for (final id in _removedAlertIds) {
        await StorageService.deleteAlert(id);
        await NotificationService.cancelNotification(
            NotificationService.idFromString(id));
      }
    } else {
      await StorageService.saveAppointment(appointment);
    }

    // Save and schedule new alerts
    for (final alertDt in _newAlerts) {
      final alertId = '${appointment.id}_${alertDt.millisecondsSinceEpoch}';
      final alert = AppointmentAlert(
        id: alertId,
        appointmentId: appointment.id,
        scheduledAt: alertDt,
      );
      await StorageService.saveAlert(alert);
      await NotificationService.scheduleOnceNotification(
        id: NotificationService.idFromString(alertId),
        title: 'Appointment Alert: ${appointment.title}',
        body: 'With ${appointment.doctorName}'
            '${appointment.location.isNotEmpty ? ' at ${appointment.location}' : ''}',
        scheduledDateTime: alertDt,
      );
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    // Existing alerts to display (excluding removed ones)
    final existingAlerts = _isEditing
        ? widget.existing!.alerts
            .where((a) => !_removedAlertIds.contains(a.id))
            .toList()
        : <AppointmentAlert>[];

    final hasAnyAlert = existingAlerts.isNotEmpty || _newAlerts.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit Appointment' : 'Add Appointment',
          style: const TextStyle(
              color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Details card
            _SectionCard(children: [
              TextFormField(
                controller: _titleController,
                decoration: _inputDecoration(
                    'Appointment Title', Icons.calendar_month_outlined),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _doctorController,
                decoration:
                    _inputDecoration("Doctor's Name", Icons.person_outlined),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? "Enter doctor's name"
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: _inputDecoration(
                    'Location / Clinic (optional)', Icons.location_on_outlined),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration:
                    _inputDecoration('Notes (optional)', Icons.notes_outlined),
              ),
            ]),
            const SizedBox(height: 16),

            // Date & time card
            _SectionCard(children: [
              _PickerTile(
                icon: Icons.calendar_today_outlined,
                label: 'Appointment Date',
                value: _appointmentDate == null
                    ? 'Select date'
                    : _formatDate(_appointmentDate!),
                onTap: _pickDate,
                hasValue: _appointmentDate != null,
              ),
              const Divider(height: 1),
              _PickerTile(
                icon: Icons.access_time_outlined,
                label: 'Appointment Time',
                value: _appointmentTime == null
                    ? 'Select time'
                    : _formatTime(_appointmentTime!),
                onTap: _pickTime,
                hasValue: _appointmentTime != null,
              ),
            ]),
            const SizedBox(height: 16),

            // Alerts card
            _SectionCard(children: [
              Row(
                children: [
                  const Icon(Icons.notifications_outlined,
                      size: 16, color: _purple),
                  const SizedBox(width: 8),
                  Text(
                    'ALERTS',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[500],
                        letterSpacing: 0.6),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addAlert,
                    icon: const Icon(Icons.add, size: 16, color: _purple),
                    label: const Text('Add Alert',
                        style: TextStyle(color: _purple, fontSize: 13)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                    ),
                  ),
                ],
              ),

              if (!hasAnyAlert) ...[
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'No alerts set — tap Add Alert to get reminders',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[400]),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 4),
              ],

              // Existing alerts (edit mode)
              ...existingAlerts.map((alert) => _AlertRow(
                    dateTime: alert.scheduledAt,
                    acknowledged: alert.acknowledged,
                    formatDt: _formatAlertDt,
                    onRemove: alert.acknowledged
                        ? null
                        : () => setState(
                            () => _removedAlertIds.add(alert.id)),
                  )),

              // Newly added alerts
              ...List.generate(_newAlerts.length, (i) => _AlertRow(
                    dateTime: _newAlerts[i],
                    acknowledged: false,
                    isNew: true,
                    formatDt: _formatAlertDt,
                    onRemove: () =>
                        setState(() => _newAlerts.removeAt(i)),
                  )),
            ]),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _isEditing
                            ? 'Update Appointment'
                            : 'Save Appointment',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _purple)),
    );
  }
}

// ── Alert row widget ────────────────────────────────────────────────────────

class _AlertRow extends StatelessWidget {
  final DateTime dateTime;
  final bool acknowledged;
  final bool isNew;
  final String Function(DateTime) formatDt;
  final VoidCallback? onRemove;

  const _AlertRow({
    required this.dateTime,
    required this.acknowledged,
    required this.formatDt,
    this.isNew = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final Color iconColor;
    final IconData iconData;
    if (acknowledged) {
      iconColor = Colors.green;
      iconData = Icons.check_circle_outline;
    } else if (isNew) {
      iconColor = const Color(0xFF8B5CF6);
      iconData = Icons.alarm_add_outlined;
    } else {
      iconColor = const Color(0xFF8B5CF6);
      iconData = Icons.alarm_outlined;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(iconData, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDt(dateTime),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: acknowledged
                        ? Colors.grey[400]
                        : const Color(0xFF1E293B),
                    decoration: acknowledged
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                if (acknowledged)
                  Text('Acknowledged',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                if (isNew)
                  Text('New — will be scheduled on save',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[400],
                          fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
              onPressed: onRemove,
              tooltip: 'Remove alert',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

// ── Shared section card ─────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool hasValue;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    required this.hasValue,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Tap to select $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.chevron_right, color: Colors.transparent, size: 22),
              Icon(icon, color: const Color(0xFF8B5CF6), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[500])),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: hasValue
                            ? const Color(0xFF1E293B)
                            : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
