import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/prescription.dart';
import '../models/prescription_alert.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

class AddPrescriptionScreen extends StatefulWidget {
  final Prescription? existing;
  const AddPrescriptionScreen({super.key, this.existing});

  @override
  State<AddPrescriptionScreen> createState() => _AddPrescriptionScreenState();
}

class _AddPrescriptionScreenState extends State<AddPrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _totalPillsController = TextEditingController();
  final _pillsPerDayController = TextEditingController();
  TimeOfDay? _notificationTime;
  final List<DateTime> _newAlerts = [];
  final Set<String> _removedAlertIds = {};
  final Set<String> _acknowledgedAlertIds = {};
  bool _saving = false;

  static const _blue = Color(0xFF3B82F6);

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _totalPillsController.addListener(() => setState(() {}));
    _pillsPerDayController.addListener(() => setState(() {}));
    if (_isEditing) {
      final p = widget.existing!;
      _nameController.text = p.name;
      _instructionsController.text = p.instructions;
      _notificationTime = p.notificationTime;
      if (p.totalPills != null) _totalPillsController.text = p.totalPills.toString();
      if (p.pillsPerDay != null) _pillsPerDayController.text = p.pillsPerDay.toString();
    }
  }

  DateTime? get _calculatedRefillDate {
    final total = int.tryParse(_totalPillsController.text.trim());
    final perDay = int.tryParse(_pillsPerDayController.text.trim());
    if (total == null || perDay == null || perDay <= 0) return null;
    return DateTime.now().add(Duration(days: (total / perDay).ceil()));
  }

  String get _refillDateDisplay {
    final d = _calculatedRefillDate;
    if (d == null) return 'Enter pill count above';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _instructionsController.dispose();
    _totalPillsController.dispose();
    _pillsPerDayController.dispose();
    super.dispose();
  }

  void _dismissFocus() => FocusScope.of(context).requestFocus(FocusNode());

  Future<void> _pickNotificationTime() async {
    _dismissFocus();
    final picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF3B82F6)),
        ),
        child: child!,
      ),
    );
    _dismissFocus();
    if (picked != null) setState(() => _notificationTime = picked);
  }

  Future<void> _addAlert() async {
    _dismissFocus();
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _blue),
        ),
        child: child!,
      ),
    );
    _dismissFocus();
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _blue),
        ),
        child: child!,
      ),
    );
    _dismissFocus();
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

  Future<void> _acknowledgeAlert(PrescriptionAlert alert) async {
    await StorageService.acknowledgePrescriptionAlert(alert.id);
    await NotificationService.cancelNotification(
        NotificationService.idFromString(alert.id));
    setState(() => _acknowledgedAlertIds.add(alert.id));
  }

  String _formatAlertDt(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final hour = dt.hour == 0 ? 12 : dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  •  $hour:$minute $period';
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Prescription'),
        content: Text('Remove "${widget.existing!.name}"?'),
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
    if (confirmed == true) {
      await StorageService.deletePrescription(widget.existing!.id);
      await NotificationService.cancelNotification(
          NotificationService.idFromString(widget.existing!.id));
      for (final alert in widget.existing!.alerts) {
        await NotificationService.cancelNotification(
            NotificationService.idFromString(alert.id));
      }
      if (!mounted) return;
      Navigator.pop(context, 'deleted');
    }
  }

  Future<void> _save() async {
    _dismissFocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final totalPills = int.tryParse(_totalPillsController.text.trim());
      final pillsPerDay = int.tryParse(_pillsPerDayController.text.trim());

      final prescription = Prescription(
        id: widget.existing?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        refillDate: _calculatedRefillDate,
        instructions: _instructionsController.text.trim(),
        notificationHour: _notificationTime?.hour,
        notificationMinute: _notificationTime?.minute,
        totalPills: _isEditing ? widget.existing!.totalPills : totalPills,
        pillsPerDay: _isEditing ? widget.existing!.pillsPerDay : pillsPerDay,
        lastDecrementDate: _isEditing ? widget.existing!.lastDecrementDate : null,
      );

      if (_isEditing) {
        await StorageService.updatePrescription(prescription);
        await NotificationService.cancelNotification(
            NotificationService.idFromString(prescription.id));
        for (final id in _removedAlertIds) {
          await StorageService.deletePrescriptionAlert(id);
          await NotificationService.cancelNotification(
              NotificationService.idFromString(id));
        }
      } else {
        await StorageService.savePrescription(prescription);
      }

      if (_notificationTime != null) {
        await NotificationService.scheduleDailyNotification(
          id: NotificationService.idFromString(prescription.id),
          title: 'Prescription Reminder',
          body: '${prescription.name} — ${prescription.instructions}',
          time: _notificationTime!,
        );
      }

      for (final alertDt in _newAlerts) {
        final alertId = '${prescription.id}_${alertDt.millisecondsSinceEpoch}';
        final alert = PrescriptionAlert(
          id: alertId,
          prescriptionId: prescription.id,
          scheduledAt: alertDt,
        );
        await StorageService.savePrescriptionAlert(alert);
        await NotificationService.scheduleOnceNotification(
          id: NotificationService.idFromString(alertId),
          title: 'Refill Reminder: ${prescription.name}',
          body: prescription.instructions.isNotEmpty
              ? prescription.instructions
              : 'Time to refill your prescription',
          scheduledDateTime: alertDt,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingAlerts = _isEditing
        ? widget.existing!.alerts
            .where((a) => !_removedAlertIds.contains(a.id))
            .toList()
        : <PrescriptionAlert>[];

    PrescriptionAlert _withLocalAck(PrescriptionAlert a) =>
        _acknowledgedAlertIds.contains(a.id)
            ? PrescriptionAlert(
                id: a.id,
                prescriptionId: a.prescriptionId,
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
          _isEditing ? 'Edit Prescription' : 'Add Prescription',
          style: const TextStyle(
            color: Color(0xFF484141),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF484141)),
        actions: _isEditing
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete prescription',
                  onPressed: _confirmDelete,
                ),
              ]
            : null,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismissFocus,
        child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionCard(
              children: [
                TextFormField(
                  controller: _nameController,
                  maxLength: 100,
                  decoration: _inputDecoration(
                      'Prescription Name', Icons.description_outlined),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter prescription name'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _instructionsController,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: _inputDecoration(
                      'Instructions (optional)', Icons.notes_outlined),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Pill count section
            _SectionCard(
              children: [
                Row(
                  children: [
                    const Icon(Icons.medication_outlined,
                        size: 16, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    Text(
                      'PILL SUPPLY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[500],
                        letterSpacing: 0.6,
                      ),
                    ),
                    if (_isEditing) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Locked after creation',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[500]),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _totalPillsController,
                        enabled: !_isEditing,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration:
                            _inputDecoration('Total Pills', Icons.medication_outlined)
                                .copyWith(
                          fillColor: _isEditing
                              ? Colors.grey.shade100
                              : const Color(0xFFF8FFFE),
                          hintText: 'e.g. 90',
                        ),
                        validator: (v) {
                          if (_isEditing) return null;
                          if (v != null && v.isNotEmpty) {
                            final n = int.tryParse(v);
                            if (n == null || n <= 0) return 'Enter a valid number';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _pillsPerDayController,
                        enabled: !_isEditing,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration:
                            _inputDecoration('Pills / Day', Icons.today_outlined)
                                .copyWith(
                          fillColor: _isEditing
                              ? Colors.grey.shade100
                              : const Color(0xFFF8FFFE),
                          hintText: 'e.g. 2',
                        ),
                        validator: (v) {
                          if (_isEditing) return null;
                          if (v != null && v.isNotEmpty) {
                            final n = int.tryParse(v);
                            if (n == null || n <= 0) return 'Enter a valid number';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                if (!_isEditing) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Optional — pill count auto-decrements daily after saving',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            _SectionCard(
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: Color(0xFF3B82F6), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Estimated Refill Date',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500])),
                          Text(
                            _refillDateDisplay,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: _calculatedRefillDate != null
                                  ? const Color(0xFFE8607C)
                                  : Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Tooltip(
                      message: 'Auto-calculated: total pills ÷ pills per day',
                      child: Icon(Icons.lock_outline,
                          size: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            _SectionCard(
              children: [
                _PickerTile(
                  icon: Icons.notifications_outlined,
                  label: 'Daily Reminder',
                  value: _notificationTime == null
                      ? 'No reminder set'
                      : _notificationTime!.format(context),
                  onTap: _pickNotificationTime,
                  hasValue: _notificationTime != null,
                  trailing: _notificationTime != null
                      ? IconButton(
                          tooltip: 'Clear reminder',
                          icon: const Icon(Icons.close,
                              size: 18, color: Colors.grey),
                          onPressed: () =>
                              setState(() => _notificationTime = null),
                        )
                      : null,
                ),
                if (_notificationTime != null) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.volume_up_outlined,
                            size: 18, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 10),
                        Text(
                          'Uses your phone\'s default notification sound',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Refill alerts card
            _SectionCard(
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_outlined,
                        size: 16, color: _blue),
                    const SizedBox(width: 8),
                    Text(
                      'REFILL ALERTS',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[500],
                          letterSpacing: 0.6),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addAlert,
                      icon: const Icon(Icons.add, size: 16, color: _blue),
                      label: const Text('Add Alert',
                          style: TextStyle(color: _blue, fontSize: 13)),
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
                      'No alerts set — tap Add Alert to get refill reminders',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],

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

                ...List.generate(
                    _newAlerts.length,
                    (i) => _AlertRow(
                          dateTime: _newAlerts[i],
                          acknowledged: false,
                          isNew: true,
                          formatDt: _formatAlertDt,
                          onRemove: () =>
                              setState(() => _newAlerts.removeAt(i)),
                        )),
              ],
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _isEditing ? 'Update Prescription' : 'Save Prescription',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF8FFFE),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3B82F6)),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
    );
  }
}

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
    final Color iconColor;
    final IconData iconData;
    if (acknowledged) {
      iconColor = Colors.green;
      iconData = Icons.check_circle_outline;
    } else if (isNew) {
      iconColor = const Color(0xFF3B82F6);
      iconData = Icons.alarm_add_outlined;
    } else {
      iconColor = const Color(0xFF3B82F6);
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
                        : const Color(0xFFE8607C),
                    decoration:
                        acknowledged ? TextDecoration.lineThrough : null,
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
          if (onAcknowledge != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onAcknowledge,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
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
          if (onRemove != null) ...[
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool hasValue;
  final Widget? trailing;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    required this.hasValue,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Tap to select $label',
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF3B82F6), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: hasValue
                          ? const Color(0xFFE8607C)
                          : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
      ),
    );
  }
}
