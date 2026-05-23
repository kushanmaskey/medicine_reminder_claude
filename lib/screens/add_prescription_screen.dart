import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/prescription.dart';
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
  DateTime? _refillDate;
  TimeOfDay? _notificationTime;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final p = widget.existing!;
      _nameController.text = p.name;
      _instructionsController.text = p.instructions;
      _refillDate = p.refillDate;
      _notificationTime = p.notificationTime;
      if (p.totalPills != null) _totalPillsController.text = p.totalPills.toString();
      if (p.pillsPerDay != null) _pillsPerDayController.text = p.pillsPerDay.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _instructionsController.dispose();
    _totalPillsController.dispose();
    _pillsPerDayController.dispose();
    super.dispose();
  }

  Future<void> _pickRefillDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _refillDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF3B82F6)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _refillDate = picked);
  }

  Future<void> _pickNotificationTime() async {
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
    if (picked != null) setState(() => _notificationTime = picked);
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
      if (!mounted) return;
      Navigator.pop(context, 'deleted');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final totalPills = int.tryParse(_totalPillsController.text.trim());
    final pillsPerDay = int.tryParse(_pillsPerDayController.text.trim());

    final prescription = Prescription(
      id: widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      refillDate: _refillDate,
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

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit Prescription' : 'Add Prescription',
          style: const TextStyle(
            color: Color(0xFFE8607C),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFE8607C)),
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionCard(
              children: [
                TextFormField(
                  controller: _nameController,
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
                  decoration:
                      _inputDecoration('Instructions', Icons.notes_outlined),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter instructions'
                      : null,
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
                _PickerTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'Refill Date (optional)',
                  value: _refillDate == null
                      ? 'Not set'
                      : '${_refillDate!.day}/${_refillDate!.month}/${_refillDate!.year}',
                  onTap: _pickRefillDate,
                  hasValue: _refillDate != null,
                  trailing: _refillDate != null
                      ? IconButton(
                          tooltip: 'Clear refill date',
                          icon: const Icon(Icons.close,
                              size: 18, color: Colors.grey),
                          onPressed: () =>
                              setState(() => _refillDate = null),
                        )
                      : null,
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
