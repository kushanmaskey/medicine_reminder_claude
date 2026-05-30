import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/vital.dart';
import '../services/storage_service.dart';

class AddVitalScreen extends StatefulWidget {
  final Vital? existing;
  final String category;

  const AddVitalScreen({
    super.key,
    this.existing,
    this.category = 'daily',
  });

  @override
  State<AddVitalScreen> createState() => _AddVitalScreenState();
}

class _AddVitalScreenState extends State<AddVitalScreen> {
  final _formKey = GlobalKey<FormState>();

  // Daily fields
  final _systolicController    = TextEditingController();
  final _diastolicController   = TextEditingController();
  final _weightController      = TextEditingController();
  final _sugarController       = TextEditingController();
  final _cholesterolController = TextEditingController();

  // Open fields
  final _eventNameController = TextEditingController();

  // Shared
  final _notesController = TextEditingController();

  String _weightUnit      = 'lbs';
  String _sugarUnit       = 'mg/dL';
  String _cholesterolUnit = 'mg/dL';
  String _riskLevel       = 'Low';
  DateTime _recordedAt    = DateTime.now();

  // Monthly fields
  DateTime? _periodDate;
  DateTime? _mammogramDate;

  bool _saving = false;

  bool get _isEditing => widget.existing != null;
  String get _category => widget.category;

  static const _teal = Color(0xFF501513);
  static const _mauve = Color(0xFF7A2420);
  static const _blue = Color(0xFF3B82F6);

  Color get _accentColor {
    switch (_category) {
      case 'monthly': return _mauve;
      case 'open':    return _blue;
      default:        return _teal;
    }
  }

  String get _screenTitle {
    if (_isEditing) {
      switch (_category) {
        case 'monthly': return 'Edit Monthly Record';
        case 'open':    return 'Edit Health Event';
        default:        return 'Edit Daily Vitals';
      }
    }
    switch (_category) {
      case 'monthly': return 'Log Monthly Record';
      case 'open':    return 'Log Health Event';
      default:        return 'Log Daily Vitals';
    }
  }

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.existing!;
      _systolicController.text    = e.bpSystolic?.toString() ?? '';
      _diastolicController.text   = e.bpDiastolic?.toString() ?? '';
      _weightController.text      = e.weight?.toString() ?? '';
      _sugarController.text       = e.sugarLevel?.toString() ?? '';
      _cholesterolController.text = e.cholesterol?.toString() ?? '';
      _eventNameController.text   = e.eventName;
      _notesController.text       = e.notes;
      _weightUnit      = e.weightUnit;
      _sugarUnit       = e.sugarUnit;
      _cholesterolUnit = e.cholesterolUnit;
      _riskLevel       = e.riskLevel;
      _recordedAt      = e.recordedAt;
      _periodDate      = e.periodDate;
      _mammogramDate   = e.mammogramDate;
    }
  }

  @override
  void dispose() {
    _systolicController.dispose();
    _diastolicController.dispose();
    _weightController.dispose();
    _sugarController.dispose();
    _cholesterolController.dispose();
    _eventNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _dismissFocus() => FocusScope.of(context).unfocus();

  Future<void> _pickDateTime() async {
    _dismissFocus();
    final date = await showDatePicker(
      context: context,
      initialDate: _recordedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(primary: _accentColor)),
        child: child!,
      ),
    );
    _dismissFocus();
    if (date == null || !mounted) return;
    // Daily vitals also pick a time; Monthly/Open just use midnight
    if (_category == 'daily') {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_recordedAt),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
              colorScheme: ColorScheme.light(primary: _accentColor)),
          child: child!,
        ),
      );
      _dismissFocus();
      if (!mounted) return;
      setState(() {
        _recordedAt = DateTime(date.year, date.month, date.day,
            time?.hour ?? 0, time?.minute ?? 0);
      });
    } else {
      setState(() => _recordedAt = DateTime(date.year, date.month, date.day));
    }
  }

  Future<DateTime?> _pickPastDate(DateTime? initial, String label) async {
    _dismissFocus();
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 30),
      lastDate: DateTime.now(),
      helpText: 'Last $label date',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(primary: _accentColor)),
        child: child!,
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text('Remove this entry?'),
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
      await StorageService.deleteVital(widget.existing!.id);
      if (!mounted) return;
      Navigator.pop(context, 'deleted');
    }
  }

  Future<void> _save() async {
    try {
      if (_formKey.currentState?.validate() != true) return;
      setState(() => _saving = true);

      final vital = Vital(
        id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        recordedAt:      _recordedAt,
        category:        _category,
        eventName:       _eventNameController.text.trim(),
        bpSystolic:      _category == 'daily' ? int.tryParse(_systolicController.text.trim()) : null,
        bpDiastolic:     _category == 'daily' ? int.tryParse(_diastolicController.text.trim()) : null,
        weight:          _category == 'daily' ? double.tryParse(_weightController.text.trim()) : null,
        weightUnit:      _weightUnit,
        sugarLevel:      _category == 'daily' ? double.tryParse(_sugarController.text.trim()) : null,
        sugarUnit:       _sugarUnit,
        cholesterol:     _category == 'daily' ? double.tryParse(_cholesterolController.text.trim()) : null,
        cholesterolUnit: _cholesterolUnit,
        periodDate:      _category == 'monthly' ? _periodDate : null,
        mammogramDate:   _category == 'monthly' ? _mammogramDate : null,
        riskLevel:       _category == 'daily' ? _riskLevel : 'Low',
        notes:           _notesController.text.trim(),
      );

      if (_isEditing) {
        await StorageService.updateVital(vital);
      } else {
        await StorageService.saveVital(vital);
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

  String _formatDateTime(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final hour   = dt.hour == 0 ? 12 : dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  •  $hour:$minute $period';
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  void _showRecommendations() {
    const amber = Color(0xFFF59E0B);
    final title = switch (_category) {
      'monthly' => 'Monthly Health Tips',
      'open'    => 'Screening Recommendations',
      _         => 'Daily Vitals Guidelines',
    };
    final tips = switch (_category) {
      'monthly' => _monthlyTips,
      'open'    => _miscTips,
      _         => _dailyTips,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lightbulb, color: amber, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF484141))),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: tips.map((t) => _TipCard(tip: t)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _screenTitle,
          style: const TextStyle(color: Color(0xFF484141), fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF484141)),
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline, color: Color(0xFFF59E0B)),
            tooltip: 'Health Recommendations',
            onPressed: _showRecommendations,
          ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
          children: [
            _buildDateSection(),
            const SizedBox(height: 16),
            if (_category == 'daily') ..._buildDailyFields(),
            if (_category == 'monthly') ..._buildMonthlyFields(),
            if (_category == 'open') ..._buildOpenFields(),
            const SizedBox(height: 16),
            _buildNotesSection(),
            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  // ── Date section ─────────────────────────────────────────────────────────

  Widget _buildDateSection() {
    final label = _category == 'daily' ? 'Date & Time' : 'Date';
    final value = _category == 'daily'
        ? _formatDateTime(_recordedAt)
        : _formatDate(_recordedAt);

    return _SectionCard(
      title: label,
      icon: Icons.access_time_outlined,
      iconColor: _accentColor,
      children: [
        InkWell(
          onTap: _pickDateTime,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined, color: _accentColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(value,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: _accentColor)),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Daily fields ──────────────────────────────────────────────────────────

  List<Widget> _buildDailyFields() => [
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _inputDecoration('Systolic', 'mmHg'),
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty) {
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 60 || n > 300) return '60–300';
                  }
                  return null;
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('/', style: TextStyle(fontSize: 24, color: Colors.grey[400], fontWeight: FontWeight.w300)),
            ),
            Expanded(
              child: TextFormField(
                controller: _diastolicController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _inputDecoration('Diastolic', 'mmHg'),
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty) {
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 30 || n > 200) return '30–200';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('e.g. 120 / 80', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
      ],
    ),
    const SizedBox(height: 16),
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration('Blood Glucose', _sugarUnit),
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty) {
                    final n = double.tryParse(v.trim());
                    if (n == null || n <= 0) return 'Enter a valid value';
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
    _SectionCard(
      title: 'Cholesterol',
      icon: Icons.biotech_outlined,
      iconColor: const Color(0xFF8B5CF6),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _cholesterolController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration('Total Cholesterol', _cholesterolUnit),
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty) {
                    final n = double.tryParse(v.trim());
                    if (n == null || n <= 0) return 'Enter a valid value';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            _UnitToggle(
              options: const ['mg/dL', 'mmol/L'],
              selected: _cholesterolUnit,
              color: const Color(0xFF8B5CF6),
              onChanged: (u) => setState(() => _cholesterolUnit = u),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Normal: below 200 mg/dL', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
      ],
    ),
    const SizedBox(height: 16),
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration('Weight', _weightUnit),
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty) {
                    final n = double.tryParse(v.trim());
                    if (n == null || n <= 0 || n > 500) return 'Enter a valid weight';
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
    _buildRiskSection(),
  ];

  // ── Monthly fields ────────────────────────────────────────────────────────

  List<Widget> _buildMonthlyFields() => [
    _SectionCard(
      title: 'Last Period',
      icon: Icons.calendar_month_outlined,
      iconColor: _mauve,
      children: [
        Text('Last menstrual period start date',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 10),
        _DatePickerTile(
          date: _periodDate,
          hint: 'Tap to set last period date',
          color: _mauve,
          onTap: () async {
            final d = await _pickPastDate(_periodDate, 'Period');
            if (d != null && mounted) setState(() => _periodDate = d);
          },
          onClear: () => setState(() => _periodDate = null),
          formatDate: _formatDate,
        ),
      ],
    ),
    const SizedBox(height: 16),
    _SectionCard(
      title: 'Mammogram',
      icon: Icons.medical_information_outlined,
      iconColor: _mauve,
      children: [
        Text('Last mammogram screening date',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 10),
        _DatePickerTile(
          date: _mammogramDate,
          hint: 'Tap to set last mammogram date',
          color: _mauve,
          onTap: () async {
            final d = await _pickPastDate(_mammogramDate, 'Mammogram');
            if (d != null && mounted) setState(() => _mammogramDate = d);
          },
          onClear: () => setState(() => _mammogramDate = null),
          formatDate: _formatDate,
        ),
      ],
    ),
  ];

  // ── Open fields ───────────────────────────────────────────────────────────

  List<Widget> _buildOpenFields() => [
    _SectionCard(
      title: 'Event / Procedure',
      icon: Icons.event_note_outlined,
      iconColor: _blue,
      children: [
        TextFormField(
          controller: _eventNameController,
          maxLength: 100,
          decoration: _inputDecoration('e.g. Colonoscopy, Eye Exam, Dental…', ''),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Enter an event name' : null,
        ),
        const SizedBox(height: 8),
        Text('Describe the procedure or health event',
            style: TextStyle(fontSize: 12, color: Colors.grey[400])),
      ],
    ),
  ];

  // ── Risk section (daily only) ─────────────────────────────────────────────

  Widget _buildRiskSection() {
    return _SectionCard(
      title: 'Overall Risk Level',
      icon: Icons.shield_outlined,
      iconColor: const Color(0xFF8B5CF6),
      children: [
        ...[
          ('Low',    const Color(0xFF22C55E), Icons.sentiment_satisfied_outlined),
          ('Medium', const Color(0xFFF97316), Icons.sentiment_neutral_outlined),
          ('High',   const Color(0xFFEF4444), Icons.sentiment_dissatisfied_outlined),
        ].map((entry) {
          final (level, color, icon) = entry;
          final selected = _riskLevel == level;
          return InkWell(
            onTap: () => setState(() => _riskLevel = level),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.10) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? color.withValues(alpha: 0.5) : Colors.grey.shade200,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Radio<String>(
                    value: level,
                    groupValue: _riskLevel,
                    activeColor: color,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (v) => setState(() => _riskLevel = v!),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    '$level Risk',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? color : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Notes section ─────────────────────────────────────────────────────────

  Widget _buildNotesSection() {
    return _SectionCard(
      title: 'Notes',
      icon: Icons.notes_outlined,
      iconColor: _accentColor,
      children: [
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: _inputDecoration('Optional notes (symptoms, context…)', ''),
        ),
      ],
    );
  }

  // ── Save button ───────────────────────────────────────────────────────────

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _saving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(
                _isEditing ? 'Update' : 'Save',
                style: const TextStyle(fontSize: 16),
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
        borderSide: BorderSide(color: _accentColor),
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

// ── Date picker tile ─────────────────────────────────────────────────────────

class _DatePickerTile extends StatelessWidget {
  final DateTime? date;
  final String hint;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final String Function(DateTime) formatDate;

  const _DatePickerTile({
    required this.date,
    required this.hint,
    required this.color,
    required this.onTap,
    required this.onClear,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: date != null ? color.withValues(alpha: 0.07) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: date != null ? color.withValues(alpha: 0.4) : Colors.grey.shade200,
            width: date != null ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.event_outlined,
                color: date != null ? color : Colors.grey[400], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                date != null ? formatDate(date!) : 'Not set — tap to select',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: date != null ? FontWeight.w600 : FontWeight.w400,
                  color: date != null ? color : Colors.grey[400],
                ),
              ),
            ),
            if (date != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, color: Colors.grey[400], size: 18),
              )
            else
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Section card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.iconColor = const Color(0xFF501513),
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
              Text(
                title.toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[500],
                    letterSpacing: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

// ── Unit toggle ───────────────────────────────────────────────────────────────

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
        return GestureDetector(
          onTap: () => onChanged(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.1) : Colors.grey.shade50,
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
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? color : Colors.grey[500],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Recommendations data & card ───────────────────────────────────────────────

typedef _Tip = ({String icon, String title, String body, Color color, String? url});

const _dailyTips = <_Tip>[
  (
    icon: '❤️', title: 'Blood Pressure',
    body: 'Normal: < 120/80 mmHg. Elevated: 120-129 systolic. High: ≥ 130/80. '
        'Reduce sodium, exercise 30 min/day, limit alcohol, manage stress.',
    color: Color(0xFFEF4444),
    url: 'https://medlineplus.gov/bloodpressure.html',
  ),
  (
    icon: '🩸', title: 'Blood Sugar',
    body: 'Fasting normal: < 100 mg/dL. Pre-diabetic: 100-125. Diabetic: ≥ 126. '
        'Post-meal (2 hrs): < 140 ideal. Limit refined carbs and sugary drinks.',
    color: Color(0xFFF97316),
    url: null,
  ),
  (
    icon: '⚖️', title: 'Body Weight',
    body: 'Healthy BMI: 18.5–24.9. Overweight: 25–29.9. Obese: ≥ 30. '
        'Aim for gradual loss of 0.5–1 lb/week through diet and regular exercise.',
    color: Color(0xFF3B82F6),
    url: null,
  ),
  (
    icon: '🧪', title: 'Cholesterol',
    body: 'Total: < 200 mg/dL ideal. LDL: < 100. HDL: > 60 is protective. '
        'Increase dietary fiber, reduce saturated fats, exercise regularly.',
    color: Color(0xFF8B5CF6),
    url: null,
  ),
];

const _monthlyTips = <_Tip>[
  (
    icon: '🗓️', title: 'Menstrual Cycle',
    body: 'A normal cycle is 21–35 days. Track duration and flow each month. '
        'See a doctor for cycles outside that range, heavy bleeding, or severe pain.',
    color: Color(0xFF7A2420),
    url: null,
  ),
  (
    icon: '🩺', title: 'Mammogram',
    body: 'Annual mammogram recommended for women 40+. '
        'Start earlier with family history of breast cancer or BRCA1/2 gene mutation.',
    color: Color(0xFF8B5CF6),
    url: null,
  ),
  (
    icon: '💊', title: 'Hormonal Health',
    body: 'Log symptoms like bloating, mood changes, or cramps alongside dates. '
        'Persistent irregularities may signal thyroid issues, PCOS, or hormonal imbalances.',
    color: Color(0xFF0EA5E9),
    url: null,
  ),
];

const _miscTips = <_Tip>[
  (
    icon: '🔬', title: 'Colonoscopy',
    body: 'Every 10 years from age 45 (average risk). Every 5 years if polyps found. '
        'Every 3–5 years with family history of colorectal cancer.',
    color: Color(0xFF22C55E),
    url: null,
  ),
  (
    icon: '💉', title: 'Vaccinations',
    body: 'Annual flu shot for everyone 6 months+. Shingles vaccine at 50+. '
        'Pneumonia vaccine at 65+. Keep a record of all vaccine dates and boosters.',
    color: Color(0xFF0EA5E9),
    url: null,
  ),
  (
    icon: '👁️', title: 'Eye & Dental Exams',
    body: 'Eye exam every 1–2 years (annually if diabetic). '
        'Dental cleaning and exam every 6 months.',
    color: Color(0xFFF97316),
    url: null,
  ),
  (
    icon: '🩻', title: 'Bone Density (DEXA)',
    body: 'Recommended for women 65+ and men 70+. Earlier if low body weight, '
        'smoking, steroid use, or prior fracture. Repeat every 1–2 years if osteopenia found.',
    color: Color(0xFF8B5CF6),
    url: null,
  ),
];

class _TipCard extends StatelessWidget {
  final _Tip tip;
  const _TipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tip.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tip.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tip.icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tip.title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tip.color)),
                const SizedBox(height: 4),
                Text(tip.body,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600], height: 1.45)),
                if (tip.url != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => launchUrl(
                      Uri.parse(tip.url!),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Text(
                      'Learn more →',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tip.color,
                        decoration: TextDecoration.underline,
                        decorationColor: tip.color,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
