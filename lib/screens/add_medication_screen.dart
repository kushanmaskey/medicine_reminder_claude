import 'package:flutter/material.dart';
import '../models/medication.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _doctorController = TextEditingController();
  final _prescriptionController = TextEditingController();
  final _instructionsController = TextEditingController();
  TimeOfDay? _notificationTime;
  bool _saving = false;

  @override
  void dispose() {
    _doctorController.dispose();
    _prescriptionController.dispose();
    _instructionsController.dispose();
    super.dispose();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final medication = Medication(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      doctorName: _doctorController.text.trim(),
      prescriptionName: _prescriptionController.text.trim(),
      instructions: _instructionsController.text.trim(),
      notificationHour: _notificationTime?.hour,
      notificationMinute: _notificationTime?.minute,
    );

    await StorageService.saveMedication(medication);

    if (_notificationTime != null) {
      await NotificationService.scheduleDailyNotification(
        id: NotificationService.idFromString(medication.id),
        title: 'Medication Reminder',
        body: '${medication.prescriptionName} — ${medication.instructions}',
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
        title: const Text(
          'Add Medication',
          style: TextStyle(
            color: Color(0xFF484141),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF484141)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionCard(
              children: [
                TextFormField(
                  controller: _doctorController,
                  maxLength: 100,
                  decoration: _inputDecoration("Doctor's Name", Icons.person_outlined).copyWith(counterText: ''),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? "Enter doctor's name" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _prescriptionController,
                  maxLength: 100,
                  decoration:
                      _inputDecoration('Prescription / Medicine Name', Icons.medication_outlined).copyWith(counterText: ''),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter medication name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _instructionsController,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: _inputDecoration('Instructions', Icons.notes_outlined),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter instructions' : null,
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
                          icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                          onPressed: () => setState(() => _notificationTime = null),
                        )
                      : null,
                ),
                if (_notificationTime != null) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.volume_up_outlined, size: 18, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 10),
                        Text(
                          'Uses your phone\'s default notification sound',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Medication', style: TextStyle(fontSize: 16)),
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
    return InkWell(
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
                          ? const Color(0xFFFF6B6B)
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
    );
  }
}
