import 'package:flutter/material.dart';
import '../models/appointment.dart';
import '../models/appointment_alert.dart';
import '../models/doctor.dart';
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

  List<Doctor> _doctorOptions = [];

  // Alert state
  final List<DateTime> _newAlerts = [];
  final Set<String> _removedAlertIds = {};
  final Set<String> _acknowledgedAlertIds = {};

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
    _doctorController.addListener(_syncTitle);
    _loadDoctors();
    _cleanPastAlerts();
  }

  Future<void> _cleanPastAlerts() async {
    if (!_isEditing) return;
    final now = DateTime.now();
    for (final alert in widget.existing!.alerts) {
      if (alert.scheduledAt.isBefore(now)) {
        await StorageService.deleteAlert(alert.id);
        await NotificationService.cancelNotification(
            NotificationService.idFromString(alert.id));
        if (mounted) setState(() => _removedAlertIds.add(alert.id));
      }
    }
  }

  Future<void> _loadDoctors() async {
    try {
      final doctors = await StorageService.getDoctors();
      if (mounted) {
        setState(() {
          _doctorOptions = doctors.where((d) => d.displayName.isNotEmpty).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _showDoctorPicker() async {
    _dismissFocus();
    final selected = await showModalBottomSheet<Doctor>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Select a Doctor',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold,
                      color: Color(0xFF484141))),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _doctorOptions.length,
              itemBuilder: (ctx, i) {
                final doctor = _doctorOptions[i];
                return ListTile(
                  leading: const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Icon(Icons.person_outlined,
                        size: 16, color: _purple),
                  ),
                  title: Text(doctor.displayName,
                      style: const TextStyle(fontSize: 14)),
                  subtitle: doctor.fullAddress.isNotEmpty
                      ? Text(doctor.fullAddress,
                          style: const TextStyle(fontSize: 12))
                      : null,
                  onTap: () => Navigator.pop(ctx, doctor),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
    if (selected != null && mounted) {
      _doctorController.text = selected.displayName;
      if (selected.fullAddress.isNotEmpty) {
        _locationController.text = selected.fullAddress;
      }
      _syncTitle();
    }
  }

  void _syncTitle() {
    final doctor = _doctorController.text.trim();
    final newTitle = doctor.isEmpty ? '' : 'Appt with $doctor';
    if (_titleController.text == newTitle) return;
    if (_titleController.text != newTitle) {
      _titleController.value = _titleController.value.copyWith(
        text: newTitle,
        selection: TextSelection.collapsed(offset: newTitle.length),
      );
    }
  }

  @override
  void dispose() {
    _doctorController.removeListener(_syncTitle);
    _titleController.dispose();
    _doctorController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _dismissFocus() => FocusScope.of(context).unfocus();

  Future<void> _pickDate() async {
    _dismissFocus();
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
    _dismissFocus();
    if (picked != null) setState(() => _appointmentDate = picked);
  }

  Future<void> _pickTime() async {
    _dismissFocus();
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
    _dismissFocus();
    if (picked != null) setState(() => _appointmentTime = picked);
  }

  Future<void> _addAlert() async {
    _dismissFocus();
    try {
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

      // Default time: appointment time if set, otherwise current time + 1 hour
      final now = DateTime.now();
      final defaultTime = _appointmentTime ??
          TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);

      final time = await showTimePicker(
        context: context,
        initialTime: defaultTime,
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _purple),
          ),
          child: child!,
        ),
      );
      if (time == null || !mounted) return;

      final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (!dt.isAfter(DateTime.now())) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Alert in the Past'),
            content: const Text(
                'Please pick a date and time that is still in the future.'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      setState(() => _newAlerts.add(dt));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add alert: ${e.toString()}')),
      );
    }
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

  Future<void> _acknowledgeAlert(AppointmentAlert alert) async {
    await StorageService.acknowledgeAlert(alert.id);
    await NotificationService.cancelNotification(
        NotificationService.idFromString(alert.id));
    setState(() => _acknowledgedAlertIds.add(alert.id));
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Appointment'),
        content: Text('Remove appointment with ${widget.existing!.doctorName}?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await StorageService.deleteAppointment(widget.existing!.id);
    for (final alert in widget.existing!.alerts) {
      await NotificationService.cancelNotification(
          NotificationService.idFromString(alert.id));
    }
    if (!mounted) return;
    Navigator.pop(context, 'deleted');
  }

  Future<void> _save() async {
    try {
      // Trigger inline field errors if form is available; also validate manually
      _formKey.currentState?.validate();
      final doctor = _doctorController.text.trim();
      if (doctor.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Doctor's name is required")),
        );
        return;
      }
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

      await NotificationService.cancelNotification(
          NotificationService.idFromString(appointment.id));

      if (_isEditing) {
        await StorageService.updateAppointment(appointment);
        for (final id in _removedAlertIds) {
          await StorageService.deleteAlert(id);
          await NotificationService.cancelNotification(
              NotificationService.idFromString(id));
        }
      } else {
        await StorageService.saveAppointment(appointment);
      }

      // Save alerts separately — alert failures don't block the appointment save.
      bool alertSaveFailed = false;
      for (final alertDt in _newAlerts) {
        try {
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
        } catch (_) {
          alertSaveFailed = true;
        }
      }

      if (!mounted) return;
      Navigator.pop(context, true);

      if (alertSaveFailed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Appointment saved. Alerts could not be saved — check Supabase RLS policy for appointment_alerts.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Could not save'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Existing alerts to display (excluding removed and past ones)
    final now = DateTime.now();
    final existingAlerts = _isEditing
        ? widget.existing!.alerts
            .where((a) =>
                !_removedAlertIds.contains(a.id) &&
                a.scheduledAt.isAfter(now))
            .toList()
        : <AppointmentAlert>[];

    // Treat locally acknowledged as acknowledged
    AppointmentAlert _withLocalAck(AppointmentAlert a) =>
        _acknowledgedAlertIds.contains(a.id)
            ? AppointmentAlert(
                id: a.id,
                appointmentId: a.appointmentId,
                scheduledAt: a.scheduledAt,
                acknowledged: true)
            : a;

    final hasAnyAlert = existingAlerts.isNotEmpty || _newAlerts.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isEditing ? 'Appointment Details' : 'Add Appointment',
          style: const TextStyle(
              color: Color(0xFF484141), fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF484141)),
        actions: _isEditing
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete appointment',
                  onPressed: _confirmDelete,
                ),
              ]
            : null,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            20, 20, 20,
            20 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            // Details card
            _SectionCard(children: [
              TextFormField(
                controller: _doctorController,
                maxLength: 100,
                decoration: _inputDecoration(
                  "Doctor's Name",
                  Icons.person_outlined,
                ).copyWith(
                  suffixIcon: _doctorOptions.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.arrow_drop_down,
                              color: _purple),
                          tooltip: 'Pick from saved doctors',
                          onPressed: _showDoctorPicker,
                        ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? "Enter doctor's name"
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                maxLength: 200,
                decoration: _inputDecoration(
                    'Location / Clinic (optional)', Icons.location_on_outlined),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                maxLength: 500,
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
              ...existingAlerts.map((alert) {
                final a = _withLocalAck(alert);
                return _AlertRow(
                  dateTime: a.scheduledAt,
                  acknowledged: a.acknowledged,
                  formatDt: _formatAlertDt,
                  onAcknowledge: a.acknowledged
                      ? null
                      : () => _acknowledgeAlert(a),
                  onRemove: a.acknowledged
                      ? null
                      : () => setState(() => _removedAlertIds.add(a.id)),
                );
              }),

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
  final VoidCallback? onAcknowledge;
  final VoidCallback? onRemove;

  const _AlertRow({
    required this.dateTime,
    required this.acknowledged,
    required this.formatDt,
    this.isNew = false,
    this.onAcknowledge,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isPast = !isNew && dateTime.isBefore(DateTime.now());
    final isDone = acknowledged || isPast;

    final Color iconColor;
    final IconData iconData;
    if (isDone) {
      iconColor = Colors.grey.shade400;
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
                    color: isDone ? Colors.grey[400] : const Color(0xFFFF6B6B),
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (isDone)
                  Text(isPast && !acknowledged ? 'Passed' : 'Acknowledged',
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
          if (!isDone && onAcknowledge != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onAcknowledge,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Done',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
          if (!isDone && onRemove != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
              onPressed: onRemove,
              tooltip: 'Remove alert',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
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
                            ? const Color(0xFFFF6B6B)
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
