import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/vital.dart';
import '../models/vital_reading.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class AddVitalScreen extends StatefulWidget {
  final Vital? existing;
  final String category;
  final List<Vital> sameDayHistory;
  final DateTime? initialDate;

  const AddVitalScreen({
    super.key,
    this.existing,
    this.category = 'daily',
    this.sameDayHistory = const [],
    this.initialDate,
  });

  @override
  State<AddVitalScreen> createState() => _AddVitalScreenState();
}

class _AddVitalScreenState extends State<AddVitalScreen> {
  final _formKey = GlobalKey<FormState>();

  // All readings shown in the session.
  // Readings from widget.existing have IDs recorded in _existingReadingIds.
  // Readings added this session each have their own independent Vital in the DB (id = reading.id).
  List<BpReading> _bpReadings          = [];
  List<VitalReading> _pulseReadings    = [];
  List<VitalReading> _sugarReadings    = [];
  List<VitalReading> _cholesterolReadings = [];
  List<VitalReading> _weightReadings   = [];

  // IDs of readings that came from widget.existing (not from new session Vitals)
  final Set<String> _existingReadingIds = {};

  // True once any reading has been persisted to DB this session
  bool _hasSaved = false;

  // Vitals saved this session so notes can be updated on Done
  final List<Vital> _sessionSavedVitals = [];

  // Open fields
  final _eventNameController          = TextEditingController();
  final _locationController           = TextEditingController();
  final _mammogramLocationController  = TextEditingController();
  final _colonoscopyLocationController = TextEditingController();
  final _dentalLocationController     = TextEditingController();
  final _eyeExamLocationController    = TextEditingController();

  // Shared
  final _notesController = TextEditingController();

  String _weightUnit      = 'lbs';
  String _sugarUnit       = 'mg/dL';
  String _cholesterolUnit = 'mg/dL';
  DateTime _recordedAt    = DateTime.now();

  // Misc fields
  DateTime? _periodDate;
  DateTime? _mammogramDate;
  DateTime? _colonoscopyDate;
  bool _hasEventDate = false;
  DateTime? _dentalDate;
  DateTime? _eyeExamDate;
  String? _sex;

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
      return _category == 'daily' ? 'Edit Daily Vitals' : 'Edit Misc Record';
    }
    return _category == 'daily' ? 'Log Daily Vitals' : 'Log Misc Record';
  }

  bool get _isFemale => _sex == 'Female';

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.existing!;
      _bpReadings          = List.from(e.bpReadings);
      _pulseReadings       = List.from(e.pulseReadings);
      _sugarReadings       = List.from(e.sugarReadings);
      _cholesterolReadings = List.from(e.cholesterolReadings);
      _weightReadings      = List.from(e.weightReadings);
      _existingReadingIds.addAll(e.bpReadings.map((r) => r.id));
      _existingReadingIds.addAll(e.pulseReadings.map((r) => r.id));
      _existingReadingIds.addAll(e.sugarReadings.map((r) => r.id));
      _existingReadingIds.addAll(e.cholesterolReadings.map((r) => r.id));
      _existingReadingIds.addAll(e.weightReadings.map((r) => r.id));
      _eventNameController.text            = e.eventName;
      _locationController.text             = e.location;
      _mammogramLocationController.text    = e.mammogramLocation;
      _colonoscopyLocationController.text  = e.colonoscopyLocation;
      _dentalLocationController.text       = e.dentalLocation;
      _eyeExamLocationController.text      = e.eyeExamLocation;
      _notesController.text       = e.notes;
      _weightUnit      = e.weightUnit;
      _sugarUnit       = e.sugarUnit;
      _cholesterolUnit = e.cholesterolUnit;
      _recordedAt      = e.recordedAt;
      _hasEventDate    = e.category != 'daily';
      _periodDate      = e.periodDate;
      _mammogramDate   = e.mammogramDate;
      _colonoscopyDate = e.colonoscopyDate;
      _dentalDate      = e.dentalDate;
      _eyeExamDate     = e.eyeExamDate;
    }
    if (!_isEditing && widget.initialDate != null) {
      final now = DateTime.now();
      _recordedAt = DateTime(
        widget.initialDate!.year,
        widget.initialDate!.month,
        widget.initialDate!.day,
        now.hour,
        now.minute,
      );
    }
    if (_category != 'daily') {
      AuthService.getSex().then((s) { if (mounted) setState(() => _sex = s); });
    }
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _locationController.dispose();
    _mammogramLocationController.dispose();
    _colonoscopyLocationController.dispose();
    _dentalLocationController.dispose();
    _eyeExamLocationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _dismissFocus() => FocusScope.of(context).unfocus();

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

  Future<DateTime?> _pickAnyDate(DateTime? initial, String label) async {
    _dismissFocus();
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 30),
      lastDate: DateTime(DateTime.now().year + 10),
      helpText: '$label date',
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
      if (_category != 'daily' && _eventNameController.text.trim().isNotEmpty && !_hasEventDate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a date for the event / procedure')),
        );
        return;
      }
      setState(() => _saving = true);

      final vital = Vital(
        id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        recordedAt:      _recordedAt,
        category:        _category,
        eventName:       _eventNameController.text.trim(),
        bpReadings:          _category == 'daily' ? _bpReadings : [],
        pulseReadings:       _category == 'daily' ? _pulseReadings : [],
        sugarReadings:       _category == 'daily' ? _sugarReadings : [],
        cholesterolReadings: _category == 'daily' ? _cholesterolReadings : [],
        weightReadings:      _category == 'daily' ? _weightReadings : [],
        weightUnit:      _weightUnit,
        sugarUnit:       _sugarUnit,
        cholesterolUnit: _cholesterolUnit,
        colonoscopyDate:     _category != 'daily' ? _colonoscopyDate : null,
        colonoscopyLocation: _category != 'daily' ? _colonoscopyLocationController.text.trim() : '',
        colonoscopyNotes:    '',
        periodDate:          _category != 'daily' ? _periodDate : null,
        periodNotes:         '',
        mammogramDate:       _category != 'daily' ? _mammogramDate : null,
        mammogramLocation:   _category != 'daily' ? _mammogramLocationController.text.trim() : '',
        mammogramNotes:      '',
        dentalDate:          _category != 'daily' ? _dentalDate : null,
        dentalLocation:      _category != 'daily' ? _dentalLocationController.text.trim() : '',
        dentalNotes:         '',
        eyeExamDate:         _category != 'daily' ? _eyeExamDate : null,
        eyeExamLocation:     _category != 'daily' ? _eyeExamLocationController.text.trim() : '',
        eyeExamNotes:        '',
        riskLevel:       'Low',
        notes:           _notesController.text.trim(),
        location:        _category != 'daily' ? _locationController.text.trim() : '',
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

  Vital _makeSingleReadingVital({
    required String id,
    List<BpReading> bpReadings = const [],
    List<VitalReading> pulseReadings = const [],
    List<VitalReading> sugarReadings = const [],
    List<VitalReading> cholesterolReadings = const [],
    List<VitalReading> weightReadings = const [],
  }) {
    final readingTime = bpReadings.isNotEmpty ? bpReadings.first.time
        : pulseReadings.isNotEmpty ? pulseReadings.first.time
        : sugarReadings.isNotEmpty ? sugarReadings.first.time
        : cholesterolReadings.isNotEmpty ? cholesterolReadings.first.time
        : weightReadings.isNotEmpty ? weightReadings.first.time
        : DateTime.now();

    // Keep the existing record's DATE for correct day grouping, but use the
    // reading's actual TIME so fallback display shows the right entry time.
    final recordedAt = _isEditing
        ? DateTime(_recordedAt.year, _recordedAt.month, _recordedAt.day,
                   readingTime.hour, readingTime.minute, readingTime.second)
        : readingTime;

    return Vital(
      id: id,
      recordedAt: recordedAt,
      category: _category,
      eventName: '',
      bpReadings: bpReadings,
      pulseReadings: pulseReadings,
      sugarReadings: sugarReadings,
      cholesterolReadings: cholesterolReadings,
      weightReadings: weightReadings,
      weightUnit: _weightUnit,
      sugarUnit: _sugarUnit,
      cholesterolUnit: _cholesterolUnit,
      riskLevel: 'Low',
      notes: _notesController.text.trim(),
    );
  }

  Future<void> _saveSingleReading(Vital vital) async {
    try {
      await StorageService.saveVital(vital);
      if (mounted) {
        setState(() {
          _hasSaved = true;
          _sessionSavedVitals.add(vital);
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Reading saved'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save error: $e'),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _deleteReading(String readingId) async {
    try {
      if (_existingReadingIds.contains(readingId)) {
        _existingReadingIds.remove(readingId);
        final remBp = _bpReadings.where((r) => _existingReadingIds.contains(r.id)).toList();
        final remPulse = _pulseReadings.where((r) => _existingReadingIds.contains(r.id)).toList();
        final remSugar = _sugarReadings.where((r) => _existingReadingIds.contains(r.id)).toList();
        final remCholesterol = _cholesterolReadings.where((r) => _existingReadingIds.contains(r.id)).toList();
        final remWeight = _weightReadings.where((r) => _existingReadingIds.contains(r.id)).toList();
        if (remBp.isEmpty && remPulse.isEmpty && remSugar.isEmpty && remCholesterol.isEmpty && remWeight.isEmpty) {
          await StorageService.deleteVital(widget.existing!.id);
        } else {
          final e = widget.existing!;
          await StorageService.updateVital(Vital(
            id: e.id, recordedAt: e.recordedAt, category: e.category,
            eventName: e.eventName, bpReadings: remBp, pulseReadings: remPulse,
            sugarReadings: remSugar, cholesterolReadings: remCholesterol,
            weightReadings: remWeight, weightUnit: e.weightUnit, sugarUnit: e.sugarUnit,
            cholesterolUnit: e.cholesterolUnit, riskLevel: e.riskLevel, notes: e.notes,
          ));
        }
      } else {
        await StorageService.deleteVital(readingId);
      }
      if (mounted) setState(() => _hasSaved = true);
    } catch (_) {}
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _hasSaved);
      },
      child: Scaffold(
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
          if (_category != 'daily')
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
            if (_category == 'daily') ..._buildDailyFields(context),
            if (_category != 'daily') ..._buildMiscFields(),
            const SizedBox(height: 16),
            _buildNotesSection(),
            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
      ),
    ),
    );
  }

  // ── Add / edit reading helpers ────────────────────────────────────────────

  Future<void> _addPulseReading(BuildContext context) async {
    final result = await showModalBottomSheet<VitalReading>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _VitalReadingSheet(
        label: 'Pulse Rate', unit: 'bpm', hint: 'e.g. 72',
        accentColor: Color(0xFFEC4899),
      ),
    );
    if (result != null && mounted) {
      setState(() => _pulseReadings.add(result));
      if (_category == 'daily') {
        await _saveSingleReading(
            _makeSingleReadingVital(id: result.id, pulseReadings: [result]));
      }
    }
  }

  Future<void> _addBpReading(BuildContext context) async {
    final result = await showModalBottomSheet<BpReading>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BpReadingSheet(accentColor: Color(0xFFEF4444)),
    );
    if (result != null && mounted) {
      setState(() => _bpReadings.add(result));
      if (_category == 'daily') {
        await _saveSingleReading(
            _makeSingleReadingVital(id: result.id, bpReadings: [result]));
      }
    }
  }

  Future<void> _addVitalReading(
    BuildContext context,
    List<VitalReading> list,
    String label,
    String unit,
    String hint,
    Color color,
    String type,  // 'sugar' | 'cholesterol' | 'weight'
  ) async {
    final result = await showModalBottomSheet<VitalReading>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VitalReadingSheet(
        label: label, unit: unit, hint: hint, accentColor: color,
      ),
    );
    if (result != null && mounted) {
      setState(() => list.add(result));
      if (_category == 'daily') {
        await _saveSingleReading(_makeSingleReadingVital(
          id: result.id,
          sugarReadings:       type == 'sugar'       ? [result] : [],
          cholesterolReadings: type == 'cholesterol' ? [result] : [],
          weightReadings:      type == 'weight'      ? [result] : [],
        ));
      }
    }
  }

  // ── Daily fields (multi-reading) ──────────────────────────────────────────

  /// Returns up to 3 past BP readings from OTHER vitals on the same day, newest first.
  List<(String, DateTime)> get _histBp {
    final rows = <(String, DateTime)>[];
    for (final v in widget.sameDayHistory) {
      for (final r in v.bpReadings) {
        rows.add(('${r.systolic} / ${r.diastolic} mmHg', r.time));
      }
    }
    rows.sort((a, b) => b.$2.compareTo(a.$2));
    return rows.take(3).toList();
  }

  List<(String, DateTime)> get _histPulse {
    final rows = <(String, DateTime)>[];
    for (final v in widget.sameDayHistory) {
      for (final r in v.pulseReadings) {
        rows.add(('${r.value.toInt()} bpm', r.time));
      }
    }
    rows.sort((a, b) => b.$2.compareTo(a.$2));
    return rows.take(3).toList();
  }

  List<(String, DateTime)> _histVital(
    List<VitalReading> Function(Vital) getter,
    String unit,
  ) {
    final rows = <(String, DateTime)>[];
    for (final v in widget.sameDayHistory) {
      for (final r in getter(v)) {
        rows.add(('${r.value.toStringAsFixed(1)} $unit', r.time));
      }
    }
    rows.sort((a, b) => b.$2.compareTo(a.$2));
    return rows.take(3).toList();
  }

  String _formatDateTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  List<Widget> _historyRows(List<(String, DateTime)> history, Color color) {
    if (history.isEmpty) return [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6),
        child: Text('Previous readings',
            style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w500, letterSpacing: 0.3)),
      ),
      ...history.map((h) => _HistoryRow(label: h.$1, time: _formatDateTime(h.$2), accentColor: color)),
      const Divider(height: 20, thickness: 0.5),
    ];
  }

  List<Widget> _buildDailyFields(BuildContext context) => [
    _SectionCard(
      title: 'Blood Pressure',
      icon: Icons.favorite_outlined,
      iconColor: const Color(0xFFEF4444),
      children: [
        ..._bpReadings.reversed.toList().asMap().entries.map((e) {
          final originalIndex = _bpReadings.length - 1 - e.key;
          final reading = e.value;
          return _ReadingRow(
            label: '${reading.systolic} / ${reading.diastolic} mmHg',
            time: _formatTime(reading.time),

            accentColor: const Color(0xFFEF4444),
            onDelete: () async {
              setState(() => _bpReadings.removeAt(originalIndex));
              await _deleteReading(reading.id);
            },
          );
        }),
        ..._historyRows(_histBp, const Color(0xFFEF4444)),
        _AddReadingButton(
          label: _bpReadings.isEmpty ? 'Add BP Reading' : 'Add Another',
          color: const Color(0xFFEF4444),
          onPressed: () => _addBpReading(context),
        ),
      ],
    ),
    const SizedBox(height: 16),
    _SectionCard(
      title: 'Pulse',
      icon: Icons.monitor_heart_outlined,
      iconColor: const Color(0xFFEC4899),
      children: [
        ..._pulseReadings.reversed.toList().asMap().entries.map((e) {
          final originalIndex = _pulseReadings.length - 1 - e.key;
          final reading = e.value;
          return _ReadingRow(
            label: '${reading.value.toInt()} bpm',
            time: _formatTime(reading.time),
            accentColor: const Color(0xFFEC4899),
            onDelete: () async {
              setState(() => _pulseReadings.removeAt(originalIndex));
              await _deleteReading(reading.id);
            },
          );
        }),
        ..._historyRows(_histPulse, const Color(0xFFEC4899)),
        _AddReadingButton(
          label: _pulseReadings.isEmpty ? 'Add Pulse Reading' : 'Add Another',
          color: const Color(0xFFEC4899),
          onPressed: () => _addPulseReading(context),
        ),
        const SizedBox(height: 4),
        Text('Normal resting: 60–100 bpm', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
      ],
    ),
    const SizedBox(height: 16),
    _SectionCard(
      title: 'Sugar Level',
      icon: Icons.water_drop_outlined,
      iconColor: const Color(0xFFF97316),
      trailing: _UnitToggle(
        options: const ['mg/dL', 'mmol/L'],
        selected: _sugarUnit,
        color: const Color(0xFFF97316),
        onChanged: (u) => setState(() => _sugarUnit = u),
      ),
      children: [
        ..._sugarReadings.reversed.toList().asMap().entries.map((e) {
          final originalIndex = _sugarReadings.length - 1 - e.key;
          final reading = e.value;
          return _ReadingRow(
            label: '${reading.value.toStringAsFixed(1)} $_sugarUnit',
            time: _formatTime(reading.time),

            accentColor: const Color(0xFFF97316),
            onDelete: () async {
              setState(() => _sugarReadings.removeAt(originalIndex));
              await _deleteReading(reading.id);
            },
          );
        }),
        ..._historyRows(_histVital((v) => v.sugarReadings, _sugarUnit), const Color(0xFFF97316)),
        _AddReadingButton(
          label: _sugarReadings.isEmpty ? 'Add Sugar Reading' : 'Add Another',
          color: const Color(0xFFF97316),
          onPressed: () => _addVitalReading(
            context, _sugarReadings, 'Blood Glucose', _sugarUnit, 'e.g. 95', const Color(0xFFF97316), 'sugar',
          ),
        ),
        const SizedBox(height: 4),
        Text('Fasting normal: < 100 mg/dL', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
      ],
    ),
    const SizedBox(height: 16),
    _SectionCard(
      title: 'Cholesterol',
      icon: Icons.biotech_outlined,
      iconColor: const Color(0xFF8B5CF6),
      trailing: _UnitToggle(
        options: const ['mg/dL', 'mmol/L'],
        selected: _cholesterolUnit,
        color: const Color(0xFF8B5CF6),
        onChanged: (u) => setState(() => _cholesterolUnit = u),
      ),
      children: [
        ..._cholesterolReadings.reversed.toList().asMap().entries.map((e) {
          final originalIndex = _cholesterolReadings.length - 1 - e.key;
          final reading = e.value;
          return _ReadingRow(
            label: '${reading.value.toStringAsFixed(1)} $_cholesterolUnit',
            time: _formatTime(reading.time),

            accentColor: const Color(0xFF8B5CF6),
            onDelete: () async {
              setState(() => _cholesterolReadings.removeAt(originalIndex));
              await _deleteReading(reading.id);
            },
          );
        }),
        ..._historyRows(_histVital((v) => v.cholesterolReadings, _cholesterolUnit), const Color(0xFF8B5CF6)),
        _AddReadingButton(
          label: _cholesterolReadings.isEmpty ? 'Add Cholesterol Reading' : 'Add Another',
          color: const Color(0xFF8B5CF6),
          onPressed: () => _addVitalReading(
            context, _cholesterolReadings, 'Total Cholesterol', _cholesterolUnit, 'e.g. 185', const Color(0xFF8B5CF6), 'cholesterol',
          ),
        ),
        const SizedBox(height: 4),
        Text('Normal: below 200 mg/dL', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
      ],
    ),
    const SizedBox(height: 16),
    _SectionCard(
      title: 'Weight',
      icon: Icons.scale_outlined,
      iconColor: const Color(0xFF3B82F6),
      trailing: _UnitToggle(
        options: const ['lbs', 'kg'],
        selected: _weightUnit,
        color: const Color(0xFF3B82F6),
        onChanged: (u) => setState(() => _weightUnit = u),
      ),
      children: [
        ..._weightReadings.reversed.toList().asMap().entries.map((e) {
          final originalIndex = _weightReadings.length - 1 - e.key;
          final reading = e.value;
          return _ReadingRow(
            label: '${reading.value.toStringAsFixed(1)} $_weightUnit',
            time: _formatTime(reading.time),

            accentColor: const Color(0xFF3B82F6),
            onDelete: () async {
              setState(() => _weightReadings.removeAt(originalIndex));
              await _deleteReading(reading.id);
            },
          );
        }),
        ..._historyRows(_histVital((v) => v.weightReadings, _weightUnit), const Color(0xFF3B82F6)),
        _AddReadingButton(
          label: _weightReadings.isEmpty ? 'Add Weight Reading' : 'Add Another',
          color: const Color(0xFF3B82F6),
          onPressed: () => _addVitalReading(
            context, _weightReadings, 'Weight', _weightUnit, 'e.g. 155', const Color(0xFF3B82F6), 'weight',
          ),
        ),
      ],
    ),
  ];

  // ── Misc fields ───────────────────────────────────────────────────────────

  List<Widget> _buildMiscFields() => [
    if (_isFemale) ...[
      _SectionCard(
        title: 'Period',
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
          const SizedBox(height: 12),
          Text('Location / Facility',
              style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _mammogramLocationController,
            maxLength: 150,
            textCapitalization: TextCapitalization.words,
            decoration: _inputDecoration('e.g. City Radiology Center…', ''),
          ),
        ],
      ),
      const SizedBox(height: 16),
    ],
    _SectionCard(
      title: 'Colonoscopy',
      icon: Icons.biotech_outlined,
      iconColor: const Color(0xFF0EA5E9),
      children: [
        Text('Last colonoscopy date',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 10),
        _DatePickerTile(
          date: _colonoscopyDate,
          hint: 'Tap to set last colonoscopy date',
          color: const Color(0xFF0EA5E9),
          onTap: () async {
            final d = await _pickPastDate(_colonoscopyDate, 'Colonoscopy');
            if (d != null && mounted) setState(() => _colonoscopyDate = d);
          },
          onClear: () => setState(() => _colonoscopyDate = null),
          formatDate: _formatDate,
        ),
        const SizedBox(height: 12),
        Text('Location / Facility',
            style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _colonoscopyLocationController,
          maxLength: 150,
          textCapitalization: TextCapitalization.words,
          decoration: _inputDecoration('e.g. Downtown Endoscopy Center…', ''),
        ),
      ],
    ),
    const SizedBox(height: 16),
    _SectionCard(
      title: 'Dental',
      icon: Icons.health_and_safety_outlined,
      iconColor: const Color(0xFF22C55E),
      children: [
        Text('Last dental visit date',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 10),
        _DatePickerTile(
          date: _dentalDate,
          hint: 'Tap to set last dental date',
          color: const Color(0xFF22C55E),
          onTap: () async {
            final d = await _pickPastDate(_dentalDate, 'Dental');
            if (d != null && mounted) setState(() => _dentalDate = d);
          },
          onClear: () => setState(() => _dentalDate = null),
          formatDate: _formatDate,
        ),
        const SizedBox(height: 12),
        Text('Location / Facility',
            style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _dentalLocationController,
          maxLength: 150,
          textCapitalization: TextCapitalization.words,
          decoration: _inputDecoration('e.g. Smile Dental Clinic…', ''),
        ),
      ],
    ),
    const SizedBox(height: 16),
    _SectionCard(
      title: 'Eye Exam',
      icon: Icons.visibility_outlined,
      iconColor: const Color(0xFF8B5CF6),
      children: [
        Text('Last eye exam date',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 10),
        _DatePickerTile(
          date: _eyeExamDate,
          hint: 'Tap to set last eye exam date',
          color: const Color(0xFF8B5CF6),
          onTap: () async {
            final d = await _pickPastDate(_eyeExamDate, 'Eye Exam');
            if (d != null && mounted) setState(() => _eyeExamDate = d);
          },
          onClear: () => setState(() => _eyeExamDate = null),
          formatDate: _formatDate,
        ),
        const SizedBox(height: 12),
        Text('Location / Facility',
            style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _eyeExamLocationController,
          maxLength: 150,
          textCapitalization: TextCapitalization.words,
          decoration: _inputDecoration('e.g. Vision Care Clinic…', ''),
        ),
      ],
    ),
    const SizedBox(height: 16),
    _SectionCard(
      title: 'Event / Procedure',
      icon: Icons.event_note_outlined,
      iconColor: _blue,
      children: [
        TextFormField(
          controller: _eventNameController,
          maxLength: 100,
          decoration: _inputDecoration('e.g. Eye Exam, Dental, Physiotherapy…', ''),
          onChanged: (_) => setState(() {}),
          validator: (v) {
            final hasDate = _periodDate != null || _mammogramDate != null || _colonoscopyDate != null;
            if (!hasDate && (v == null || v.trim().isEmpty)) {
              return 'Enter an event name or select a date above';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        Text('Location / Facility',
            style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _locationController,
          maxLength: 150,
          textCapitalization: TextCapitalization.words,
          decoration: _inputDecoration('e.g. City Hospital, Downtown Clinic…', ''),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text('Event Date',
                style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
            if (_eventNameController.text.trim().isNotEmpty)
              Text(' *', style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
            if (_eventNameController.text.trim().isEmpty)
              Text(' (optional)', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          ],
        ),
        const SizedBox(height: 6),
        _DatePickerTile(
          date: _hasEventDate ? _recordedAt : null,
          hint: 'Tap to set event date',
          color: _blue,
          onTap: () async {
            final d = await _pickAnyDate(_recordedAt, 'Event');
            if (d != null && mounted) setState(() { _recordedAt = d; _hasEventDate = true; });
          },
          onClear: () => setState(() { _recordedAt = DateTime.now(); _hasEventDate = false; }),
          formatDate: _formatDate,
        ),
        if (_eventNameController.text.trim().isNotEmpty && !_hasEventDate) ...[
          const SizedBox(height: 4),
          const Text('Date is required when an event name is entered',
              style: TextStyle(fontSize: 11, color: Colors.red)),
        ] else ...[
          const SizedBox(height: 4),
          Text('When the event or procedure took place',
              style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ],
      ],
    ),
  ];

  Future<void> _doneDaily() async {
    final notes = _notesController.text.trim();
    // Update notes on vitals saved this session if notes changed
    for (final v in _sessionSavedVitals) {
      if (v.notes != notes) {
        try {
          await StorageService.updateVital(Vital(
            id: v.id, recordedAt: v.recordedAt, category: v.category,
            eventName: v.eventName, bpReadings: v.bpReadings, pulseReadings: v.pulseReadings,
            sugarReadings: v.sugarReadings, cholesterolReadings: v.cholesterolReadings,
            weightReadings: v.weightReadings, weightUnit: v.weightUnit,
            sugarUnit: v.sugarUnit, cholesterolUnit: v.cholesterolUnit,
            riskLevel: v.riskLevel, notes: notes,
          ));
          _hasSaved = true;
        } catch (_) {}
      }
    }
    // Update existing vital's notes when editing
    if (_isEditing && widget.existing!.notes != notes) {
      try {
        final e = widget.existing!;
        await StorageService.updateVital(Vital(
          id: e.id, recordedAt: e.recordedAt, category: e.category,
          eventName: e.eventName, bpReadings: _bpReadings, pulseReadings: _pulseReadings,
          sugarReadings: _sugarReadings, cholesterolReadings: _cholesterolReadings,
          weightReadings: _weightReadings, weightUnit: _weightUnit,
          sugarUnit: _sugarUnit, cholesterolUnit: _cholesterolUnit,
          riskLevel: e.riskLevel, notes: notes, doctorId: e.doctorId, location: e.location,
        ));
        _hasSaved = true;
      } catch (_) {}
    }
    if (mounted) Navigator.pop(context, _hasSaved);
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
    if (_category == 'daily') {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton(
          onPressed: _doneDaily,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _accentColor),
            foregroundColor: _accentColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Save', style: TextStyle(fontSize: 16)),
        ),
      );
    }
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

// ── Reading row ───────────────────────────────────────────────────────────────

// ── History row (read-only, no delete) ───────────────────────────────────────

class _HistoryRow extends StatelessWidget {
  final String label;
  final String time;
  final Color accentColor;

  const _HistoryRow({
    required this.label,
    required this.time,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(Icons.history, size: 14, color: Colors.grey[400]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[600])),
          ),
          Text(time, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ],
      ),
    );
  }
}

// ── Current-session reading row ───────────────────────────────────────────────

class _ReadingRow extends StatelessWidget {
  final String label;
  final String time;
  final Color accentColor;
  final VoidCallback onDelete;

  const _ReadingRow({
    required this.label,
    required this.time,
    required this.accentColor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey[400]),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
    );
  }
}

// ── Add reading button ────────────────────────────────────────────────────────

class _AddReadingButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _AddReadingButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(Icons.add, size: 16, color: color),
        label: Text(label, style: TextStyle(color: color, fontSize: 13)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

// ── BP reading sheet ──────────────────────────────────────────────────────────

class _BpReadingSheet extends StatefulWidget {
  final BpReading? initial;
  final Color accentColor;

  const _BpReadingSheet({this.initial, required this.accentColor});

  @override
  State<_BpReadingSheet> createState() => _BpReadingSheetState();
}

class _BpReadingSheetState extends State<_BpReadingSheet> {
  final _systolicCtrl  = TextEditingController();
  final _diastolicCtrl = TextEditingController();
  late DateTime _time;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _systolicCtrl.text  = init != null ? '${init.systolic}' : '';
    _diastolicCtrl.text = init != null ? '${init.diastolic}' : '';
    _time               = init?.time ?? DateTime.now();
  }

  @override
  void dispose() {
    _systolicCtrl.dispose();
    _diastolicCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_time),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: widget.accentColor),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _time = DateTime(_time.year, _time.month, _time.day, picked.hour, picked.minute);
      });
    }
  }

  String _fmt(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  void _submit() {
    final sys = int.tryParse(_systolicCtrl.text.trim());
    final dia = int.tryParse(_diastolicCtrl.text.trim());
    if (sys == null || dia == null || sys < 60 || sys > 300 || dia < 30 || dia > 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid systolic (60–300) and diastolic (30–200)')),
      );
      return;
    }
    final reading = BpReading(
      id: widget.initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      systolic: sys,
      diastolic: dia,
      time: _time,
    );
    Navigator.pop(context, reading);
  }

  @override
  Widget build(BuildContext context) {
    return _ReadingSheetShell(
      title: widget.initial != null ? 'Edit BP Reading' : 'Add BP Reading',
      accentColor: widget.accentColor,
      onSave: _submit,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _systolicCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _sheetInput('Systolic', 'mmHg', widget.accentColor),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('/', style: TextStyle(fontSize: 24, color: Colors.grey[400], fontWeight: FontWeight.w300)),
              ),
              Expanded(
                child: TextField(
                  controller: _diastolicCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _sheetInput('Diastolic', 'mmHg', widget.accentColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TimeRow(time: _fmt(_time), color: widget.accentColor, onTap: _pickTime),
        ],
      ),
    );
  }
}

// ── Generic vital reading sheet ───────────────────────────────────────────────

class _VitalReadingSheet extends StatefulWidget {
  final VitalReading? initial;
  final String label;
  final String unit;
  final String hint;
  final Color accentColor;

  const _VitalReadingSheet({
    this.initial,
    required this.label,
    required this.unit,
    required this.hint,
    required this.accentColor,
  });

  @override
  State<_VitalReadingSheet> createState() => _VitalReadingSheetState();
}

class _VitalReadingSheetState extends State<_VitalReadingSheet> {
  final _valueCtrl = TextEditingController();
  late DateTime _time;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _valueCtrl.text = init != null ? init.value.toStringAsFixed(1) : '';
    _time           = init?.time ?? DateTime.now();
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_time),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: widget.accentColor),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _time = DateTime(_time.year, _time.month, _time.day, picked.hour, picked.minute);
      });
    }
  }

  String _fmt(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  void _submit() {
    final val = double.tryParse(_valueCtrl.text.trim());
    if (val == null || val <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter a valid ${widget.label.toLowerCase()} value')),
      );
      return;
    }
    final reading = VitalReading(
      id: widget.initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      value: val,
      time: _time,
    );
    Navigator.pop(context, reading);
  }

  @override
  Widget build(BuildContext context) {
    return _ReadingSheetShell(
      title: widget.initial != null ? 'Edit ${widget.label}' : 'Add ${widget.label}',
      accentColor: widget.accentColor,
      onSave: _submit,
      child: Column(
        children: [
          TextField(
            controller: _valueCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _sheetInput(widget.hint, widget.unit, widget.accentColor),
          ),
          const SizedBox(height: 12),
          _TimeRow(time: _fmt(_time), color: widget.accentColor, onTap: _pickTime),
        ],
      ),
    );
  }
}

// ── Shared shell for reading sheets ──────────────────────────────────────────

class _ReadingSheetShell extends StatelessWidget {
  final String title;
  final Color accentColor;
  final VoidCallback onSave;
  final Widget child;

  const _ReadingSheetShell({
    required this.title,
    required this.accentColor,
    required this.onSave,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF484141))),
          const SizedBox(height: 16),
          child,
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save Reading', style: TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Time row ──────────────────────────────────────────────────────────────────

class _TimeRow extends StatelessWidget {
  final String time;
  final Color color;
  final VoidCallback onTap;

  const _TimeRow({required this.time, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, size: 18, color: color),
            const SizedBox(width: 10),
            Text(time, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
            const Spacer(),
            Text('Tap to change', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }
}

InputDecoration _sheetInput(String label, String suffix, Color accentColor) {
  return InputDecoration(
    labelText: label,
    suffixText: suffix.isNotEmpty ? suffix : null,
    filled: true,
    fillColor: const Color(0xFFF5F7FA),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: accentColor),
    ),
  );
}

// ── Date picker tile ──────────────────────────────────────────────────────────

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

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.iconColor = const Color(0xFF501513),
    required this.children,
    this.trailing,
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
              if (trailing != null) ...[
                const Spacer(),
                trailing!,
              ],
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return GestureDetector(
          onTap: () => onChanged(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                fontSize: 11,
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
    url: 'https://medlineplus.gov/highbloodpressure.html',
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
