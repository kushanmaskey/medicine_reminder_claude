import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/vital.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class AddVitalScreen extends StatefulWidget {
  final Vital? existing;
  const AddVitalScreen({super.key, this.existing});

  @override
  State<AddVitalScreen> createState() => _AddVitalScreenState();
}

class _AddVitalScreenState extends State<AddVitalScreen> {
  final _formKey = GlobalKey<FormState>();

  final _systolicController     = TextEditingController();
  final _diastolicController    = TextEditingController();
  final _weightController       = TextEditingController();
  final _sugarController        = TextEditingController();
  final _cholesterolController  = TextEditingController();
  final _notesController        = TextEditingController();

  String _weightUnit       = 'lbs';
  String _sugarUnit        = 'mg/dL';
  String _cholesterolUnit  = 'mg/dL';
  String _riskLevel        = 'Low';
  DateTime _recordedAt     = DateTime.now();

  DateTime? _colonoscopyDate;
  DateTime? _periodDate;
  DateTime? _mammogramDate;

  String? _sex;
  bool _sexLoaded = false;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;
  // Show female-specific fields when sex is Female OR when sex is not yet set
  // (null means the account predates the sex feature — show everything).
  bool get _isMaleOnly => _sex == 'Male';
  static const _teal  = Color(0xFFE8607C);
  static const _pink  = Color(0xFFEC4899);

  Color get _accentColor => _isMaleOnly ? _teal : _pink;

  @override
  void initState() {
    super.initState();
    _loadSex();
    if (_isEditing) {
      final e = widget.existing!;
      _systolicController.text    = e.bpSystolic?.toString() ?? '';
      _diastolicController.text   = e.bpDiastolic?.toString() ?? '';
      _weightController.text      = e.weight?.toString() ?? '';
      _sugarController.text       = e.sugarLevel?.toString() ?? '';
      _cholesterolController.text = e.cholesterol?.toString() ?? '';
      _notesController.text       = e.notes;
      _weightUnit      = e.weightUnit;
      _sugarUnit       = e.sugarUnit;
      _cholesterolUnit = e.cholesterolUnit;
      _riskLevel       = e.riskLevel;
      _recordedAt      = e.recordedAt;
      _colonoscopyDate = e.colonoscopyDate;
      _periodDate      = e.periodDate;
      _mammogramDate   = e.mammogramDate;
    }
  }

  Future<void> _loadSex() async {
    final sex = await AuthService.getSex();
    if (mounted) setState(() { _sex = sex; _sexLoaded = true; });
  }

  @override
  void dispose() {
    _systolicController.dispose();
    _diastolicController.dispose();
    _weightController.dispose();
    _sugarController.dispose();
    _cholesterolController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ── Date / time pickers ────────────────────────────────────────────────────

  void _dismissFocus() => FocusScope.of(context).requestFocus(FocusNode());

  Future<void> _pickDateTime() async {
    _dismissFocus();
    final date = await showDatePicker(
      context: context,
      initialDate: _recordedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(primary: _accentColor)),
        child: child!,
      ),
    );
    _dismissFocus();
    if (date == null || !mounted) return;
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
    if (time == null) return;
    setState(() {
      _recordedAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
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

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reading'),
        content: const Text('Remove this vitals reading?'),
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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final vital = Vital(
      id: widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      recordedAt:      _recordedAt,
      bpSystolic:      int.tryParse(_systolicController.text.trim()),
      bpDiastolic:     int.tryParse(_diastolicController.text.trim()),
      weight:          double.tryParse(_weightController.text.trim()),
      weightUnit:      _weightUnit,
      sugarLevel:      double.tryParse(_sugarController.text.trim()),
      sugarUnit:       _sugarUnit,
      cholesterol:     double.tryParse(_cholesterolController.text.trim()),
      cholesterolUnit: _cholesterolUnit,
      colonoscopyDate: _colonoscopyDate,
      periodDate:      _periodDate,
      mammogramDate:   _mammogramDate,
      riskLevel:       _riskLevel,
      notes:           _notesController.text.trim(),
    );

    if (_isEditing) {
      await StorageService.updateVital(vital);
    } else {
      await StorageService.saveVital(vital);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final hour   = dt.hour == 0 ? 12 : dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  •  $hour:$minute $period';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
              color: Color(0xFF484141), fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF484141)),
        actions: _isEditing
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete reading',
                  onPressed: _confirmDelete,
                ),
              ]
            : null,
      ),
      body: !_sexLoaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildDateTimeSection(),
                  const SizedBox(height: 16),
                  _buildBPSection(),
                  const SizedBox(height: 16),
                  _buildSugarSection(),
                  const SizedBox(height: 16),
                  _buildCholesterolSection(),
                  const SizedBox(height: 16),
                  _buildWeightSection(),
                  const SizedBox(height: 16),
                  _buildColonoscopySection(),
                  if (!_isMaleOnly) ...[
                    const SizedBox(height: 16),
                    _buildPeriodSection(),
                    const SizedBox(height: 16),
                    _buildMammogramSection(),
                  ],
                  const SizedBox(height: 16),
                  _buildRiskSection(),
                  const SizedBox(height: 16),
                  _buildNotesSection(),
                  const SizedBox(height: 32),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  // ── Sections ───────────────────────────────────────────────────────────────

  Widget _buildDateTimeSection() {
    return _SectionCard(
      title: 'Date & Time',
      icon: Icons.access_time_outlined,
      iconColor: _accentColor,
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
                  Icon(Icons.calendar_today_outlined,
                      color: _accentColor, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _formatDateTime(_recordedAt),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFE8607C)),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBPSection() {
    return _SectionCard(
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
                    if (n == null || n < 60 || n > 300) return 'Enter 60–300';
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _inputDecoration('Diastolic', 'mmHg'),
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty) {
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 30 || n > 200) return 'Enter 30–200';
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
    );
  }

  Widget _buildSugarSection() {
    return _SectionCard(
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
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
    );
  }

  Widget _buildCholesterolSection() {
    return _SectionCard(
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
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    _inputDecoration('Total Cholesterol', _cholesterolUnit),
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
        Text(
          'Normal: below 200 mg/dL',
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
        ),
      ],
    );
  }

  Widget _buildWeightSection() {
    return _SectionCard(
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
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
    );
  }

  Widget _buildColonoscopySection() {
    return _SectionCard(
      title: 'Colonoscopy',
      icon: Icons.medical_services_outlined,
      iconColor: const Color(0xFF14B8A6),
      children: [
        Text(
          'Last colonoscopy date',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 10),
        _DatePickerTile(
          date: _colonoscopyDate,
          hint: 'Tap to set last colonoscopy date',
          color: const Color(0xFF14B8A6),
          onTap: () async {
            final d = await _pickPastDate(_colonoscopyDate, 'Colonoscopy');
            if (d != null) setState(() => _colonoscopyDate = d);
          },
          onClear: () => setState(() => _colonoscopyDate = null),
          formatDate: _formatDate,
        ),
      ],
    );
  }

  Widget _buildPeriodSection() {
    return _SectionCard(
      title: 'Last Period',
      icon: Icons.calendar_month_outlined,
      iconColor: _pink,
      children: [
        Text(
          'Last menstrual period start date',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 10),
        _DatePickerTile(
          date: _periodDate,
          hint: 'Tap to set last period date',
          color: _pink,
          onTap: () async {
            final d = await _pickPastDate(_periodDate, 'Period');
            if (d != null) setState(() => _periodDate = d);
          },
          onClear: () => setState(() => _periodDate = null),
          formatDate: _formatDate,
        ),
      ],
    );
  }

  Widget _buildMammogramSection() {
    return _SectionCard(
      title: 'Mammogram',
      icon: Icons.medical_information_outlined,
      iconColor: _pink,
      children: [
        Text(
          'Last mammogram screening date',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 10),
        _DatePickerTile(
          date: _mammogramDate,
          hint: 'Tap to set last mammogram date',
          color: _pink,
          onTap: () async {
            final d = await _pickPastDate(_mammogramDate, 'Mammogram');
            if (d != null) setState(() => _mammogramDate = d);
          },
          onClear: () => setState(() => _mammogramDate = null),
          formatDate: _formatDate,
        ),
      ],
    );
  }

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
    );
  }

  Widget _buildNotesSection() {
    return _SectionCard(
      title: 'Notes',
      icon: Icons.notes_outlined,
      iconColor: _accentColor,
      children: [
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration:
              _inputDecoration('Optional notes (symptoms, context…)', ''),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Tooltip(
      message: _isEditing
          ? 'Save changes to this vitals entry'
          : 'Save this vitals reading',
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentColor,
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

// ── Date picker tile ────────────────────────────────────────────────────────

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
    return Tooltip(
      message: hint,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: date != null
                ? color.withValues(alpha: 0.07)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: date != null
                  ? color.withValues(alpha: 0.4)
                  : Colors.grey.shade200,
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
                    fontWeight:
                        date != null ? FontWeight.w600 : FontWeight.w400,
                    color: date != null ? color : Colors.grey[400],
                  ),
                ),
              ),
              if (date != null)
                Tooltip(
                  message: 'Clear date',
                  child: GestureDetector(
                    onTap: onClear,
                    child: Icon(Icons.close,
                        color: Colors.grey[400], size: 18),
                  ),
                )
              else
                Icon(Icons.chevron_right,
                    color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section card ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.iconColor = const Color(0xFFE8607C),
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

// ── Unit toggle ─────────────────────────────────────────────────────────────

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
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
