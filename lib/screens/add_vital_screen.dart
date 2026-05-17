import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/vital.dart';
import '../services/storage_service.dart';

class AddVitalScreen extends StatefulWidget {
  final Vital? existing;
  const AddVitalScreen({super.key, this.existing});

  @override
  State<AddVitalScreen> createState() => _AddVitalScreenState();
}

class _AddVitalScreenState extends State<AddVitalScreen> {
  final _formKey = GlobalKey<FormState>();

  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _weightController = TextEditingController();
  final _sugarController = TextEditingController();
  final _notesController = TextEditingController();

  String _weightUnit = 'kg';
  String _sugarUnit = 'mg/dL';
  String _riskLevel = 'Low';
  DateTime _recordedAt = DateTime.now();

  bool _saving = false;
  bool get _isEditing => widget.existing != null;

  static const _teal = Color(0xFF0D9488);

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.existing!;
      _systolicController.text = e.bpSystolic?.toString() ?? '';
      _diastolicController.text = e.bpDiastolic?.toString() ?? '';
      _weightController.text = e.weight?.toString() ?? '';
      _sugarController.text = e.sugarLevel?.toString() ?? '';
      _notesController.text = e.notes;
      _weightUnit = e.weightUnit;
      _sugarUnit = e.sugarUnit;
      _riskLevel = e.riskLevel;
      _recordedAt = e.recordedAt;
    }
  }

  @override
  void dispose() {
    _systolicController.dispose();
    _diastolicController.dispose();
    _weightController.dispose();
    _sugarController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _recordedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx)
            .copyWith(colorScheme: const ColorScheme.light(primary: _teal)),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_recordedAt),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx)
            .copyWith(colorScheme: const ColorScheme.light(primary: _teal)),
        child: child!,
      ),
    );
    if (time == null) return;

    setState(() {
      _recordedAt = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final vital = Vital(
      id: widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      recordedAt: _recordedAt,
      bpSystolic: int.tryParse(_systolicController.text.trim()),
      bpDiastolic: int.tryParse(_diastolicController.text.trim()),
      weight: double.tryParse(_weightController.text.trim()),
      weightUnit: _weightUnit,
      sugarLevel: double.tryParse(_sugarController.text.trim()),
      sugarUnit: _sugarUnit,
      riskLevel: _riskLevel,
      notes: _notesController.text.trim(),
    );

    if (_isEditing) {
      await StorageService.updateVital(vital);
    } else {
      await StorageService.saveVital(vital);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour == 0 ? 12 : dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  •  $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit Vitals' : 'Log Vitals',
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
            // Date & Time
            _SectionCard(
              title: 'Date & Time',
              icon: Icons.access_time_outlined,
              children: [
                Tooltip(
                  message: 'Tap to change date and time',
                  child: InkWell(
                  onTap: _pickDateTime,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            color: _teal, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _formatDateTime(_recordedAt),
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1E293B)),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                  ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Blood Pressure
            _SectionCard(
              title: 'Blood Pressure',
              icon: Icons.favorite_outlined,
              iconColor: const Color(0xFFEF4444),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _systolicController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: _inputDecoration('Systolic', 'mmHg'),
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            final n = int.tryParse(v.trim());
                            if (n == null || n < 60 || n > 300) {
                              return 'Enter 60–300';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('/',
                          style: TextStyle(
                              fontSize: 24,
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w300)),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: _diastolicController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: _inputDecoration('Diastolic', 'mmHg'),
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            final n = int.tryParse(v.trim());
                            if (n == null || n < 30 || n > 200) {
                              return 'Enter 30–200';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('e.g. 120 / 80',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400])),
              ],
            ),

            const SizedBox(height: 16),

            // Weight
            _SectionCard(
              title: 'Weight',
              icon: Icons.scale_outlined,
              iconColor: const Color(0xFF3B82F6),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: _inputDecoration('Weight', _weightUnit),
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            final n = double.tryParse(v.trim());
                            if (n == null || n <= 0 || n > 500) {
                              return 'Enter a valid weight';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    _UnitToggle(
                      options: const ['kg', 'lbs'],
                      selected: _weightUnit,
                      color: const Color(0xFF3B82F6),
                      onChanged: (u) => setState(() => _weightUnit = u),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Sugar Level
            _SectionCard(
              title: 'Sugar Level',
              icon: Icons.water_drop_outlined,
              iconColor: const Color(0xFFF97316),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _sugarController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            _inputDecoration('Blood Glucose', _sugarUnit),
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            final n = double.tryParse(v.trim());
                            if (n == null || n <= 0) {
                              return 'Enter a valid value';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    _UnitToggle(
                      options: const ['mg/dL', 'mmol/L'],
                      selected: _sugarUnit,
                      color: const Color(0xFFF97316),
                      onChanged: (u) => setState(() => _sugarUnit = u),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Risk Level
            _SectionCard(
              title: 'Risk Level',
              icon: Icons.shield_outlined,
              iconColor: const Color(0xFF8B5CF6),
              children: [
                ...[
                  ('Low', const Color(0xFF22C55E),
                      Icons.sentiment_satisfied_outlined),
                  ('Medium', const Color(0xFFF97316),
                      Icons.sentiment_neutral_outlined),
                  ('High', const Color(0xFFEF4444),
                      Icons.sentiment_dissatisfied_outlined),
                ].map((entry) {
                  final (level, color, icon) = entry;
                  final selected = _riskLevel == level;
                  return Tooltip(
                    message: 'Select $level risk level',
                    child: InkWell(
                    onTap: () => setState(() => _riskLevel = level),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? color.withValues(alpha: 0.10)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? color.withValues(alpha: 0.5)
                              : Colors.grey.shade200,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: level,
                            groupValue: _riskLevel,
                            activeColor: color,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onChanged: (v) =>
                                setState(() => _riskLevel = v!),
                          ),
                          const SizedBox(width: 8),
                          Icon(icon, color: color, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            '$level Risk',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? color
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ),
                  );
                }),
              ],
            ),

            const SizedBox(height: 16),

            // Notes
            _SectionCard(
              title: 'Notes',
              icon: Icons.notes_outlined,
              children: [
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: _inputDecoration(
                      'Optional notes (symptoms, context…)', ''),
                ),
              ],
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
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
                        _isEditing ? 'Update Vitals' : 'Save Vitals',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String suffix) {
    return InputDecoration(
      labelText: label,
      suffixText: suffix.isNotEmpty ? suffix : null,
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
        borderSide: const BorderSide(color: _teal),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.iconColor = const Color(0xFF0D9488),
    required this.children,
  });

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
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[500],
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  final List<String> options;
  final String selected;
  final Color color;
  final ValueChanged<String> onChanged;

  const _UnitToggle({
    required this.options,
    required this.selected,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options.map((opt) {
        final isSelected = opt == selected;
        return Tooltip(
          message: 'Use $opt',
          child: GestureDetector(
          onTap: () => onChanged(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.1)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? color : Colors.grey.shade200,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? color : Colors.grey[500],
              ),
            ),
          ),
          ),
        );
      }).toList(),
    );
  }
}
