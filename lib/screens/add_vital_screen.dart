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

  void _onVitalChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    for (final c in [_systolicController, _diastolicController, _sugarController, _cholesterolController, _weightController]) {
      c.addListener(_onVitalChanged);
    }
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
    for (final c in [_systolicController, _diastolicController, _sugarController, _cholesterolController, _weightController]) {
      c.removeListener(_onVitalChanged);
    }
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

  // ── Daily fields ──────────────────────────────────────────────────────────

  // ── Bulb colors (live — recomputed on every setState) ────────────────────

  static const _bulbAmber = Color(0xFFF59E0B);

  Color get _bpBulbColor => switch (_classifyBp()) {
    _BpCategory.crisis   => const Color(0xFF7F1D1D),
    _BpCategory.stage2   => const Color(0xFFEF4444),
    _BpCategory.stage1   => const Color(0xFFF97316),
    _BpCategory.elevated => const Color(0xFFEAB308),
    _BpCategory.normal   => const Color(0xFF22C55E),
    _BpCategory.low      => const Color(0xFF3B82F6),
    _BpCategory.unknown  => _bulbAmber,
  };

  Color get _sugarBulbColor => switch (_classifySugar()) {
    _SugarCategory.low         => const Color(0xFF3B82F6),
    _SugarCategory.normal      => const Color(0xFF22C55E),
    _SugarCategory.preDiabetes => const Color(0xFFEAB308),
    _SugarCategory.diabetic    => const Color(0xFFEF4444),
    _SugarCategory.unknown     => _bulbAmber,
  };

  Color get _cholesterolBulbColor => switch (_classifyCholesterol()) {
    _CholesterolCategory.optimal    => const Color(0xFF22C55E),
    _CholesterolCategory.borderline => const Color(0xFFEAB308),
    _CholesterolCategory.high       => const Color(0xFFEF4444),
    _CholesterolCategory.unknown    => _bulbAmber,
  };

  Color get _weightBulbColor => switch (_classifyWeight()) {
    _WeightCategory.low     => const Color(0xFF3B82F6),
    _WeightCategory.normal  => const Color(0xFF22C55E),
    _WeightCategory.high    => const Color(0xFFEAB308),
    _WeightCategory.veryHigh=> const Color(0xFFEF4444),
    _WeightCategory.unknown => _bulbAmber,
  };

  // ── Bulb tooltips (live) ──────────────────────────────────────────────────

  String get _bpTooltip => switch (_classifyBp()) {
    _BpCategory.crisis   => 'Hypertensive Crisis',
    _BpCategory.stage2   => 'High BP — Stage 2',
    _BpCategory.stage1   => 'High BP — Stage 1',
    _BpCategory.elevated => 'Elevated BP',
    _BpCategory.normal   => 'Normal BP',
    _BpCategory.low      => 'Low BP',
    _BpCategory.unknown  => 'Blood pressure guide',
  };

  String get _sugarTooltip => switch (_classifySugar()) {
    _SugarCategory.low         => 'Low Blood Sugar',
    _SugarCategory.normal      => 'Normal Blood Sugar',
    _SugarCategory.preDiabetes => 'Pre-Diabetes Range',
    _SugarCategory.diabetic    => 'Diabetic Range',
    _SugarCategory.unknown     => 'Blood sugar guide',
  };

  String get _cholesterolTooltip => switch (_classifyCholesterol()) {
    _CholesterolCategory.optimal    => 'Optimal Cholesterol',
    _CholesterolCategory.borderline => 'Borderline High Cholesterol',
    _CholesterolCategory.high       => 'High Cholesterol',
    _CholesterolCategory.unknown    => 'Cholesterol guide',
  };

  String get _weightTooltip => switch (_classifyWeight()) {
    _WeightCategory.low      => 'Low Weight',
    _WeightCategory.normal   => 'Healthy Weight Range',
    _WeightCategory.high     => 'Above Average Weight',
    _WeightCategory.veryHigh => 'High Weight',
    _WeightCategory.unknown  => 'Weight guide',
  };

  // ── Blood pressure classification ─────────────────────────────────────────

  _BpCategory _classifyBp() {
    final sys = int.tryParse(_systolicController.text.trim());
    final dia = int.tryParse(_diastolicController.text.trim());
    if (sys == null && dia == null) return _BpCategory.unknown;
    if ((sys != null && sys > 180) || (dia != null && dia > 120)) return _BpCategory.crisis;
    if ((sys != null && sys >= 140) || (dia != null && dia >= 90)) return _BpCategory.stage2;
    if ((sys != null && sys >= 130) || (dia != null && dia >= 80)) return _BpCategory.stage1;
    if (sys != null && sys >= 120 && (dia == null || dia < 80)) return _BpCategory.elevated;
    if ((sys != null && sys < 90) || (dia != null && dia < 60)) return _BpCategory.low;
    return _BpCategory.normal;
  }

  // ── Shared vital recommendation sheet ────────────────────────────────────────

  void _showVitalInfoSheet(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String label,
    String? reading,
    required String detail,
    String? learnMoreUrl,
    String? learnMoreLabel,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
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
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
                      if (reading != null)
                        Text(reading, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(detail, style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5)),
            if (learnMoreUrl != null) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => launchUrl(Uri.parse(learnMoreUrl), mode: LaunchMode.externalApplication),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.open_in_new, size: 16, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          learnMoreLabel ?? 'Learn more',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Blood pressure recommendation ─────────────────────────────────────────

  void _showBpRecommendation(BuildContext context) {
    final cat = _classifyBp();
    final sys = _systolicController.text.trim();
    final dia = _diastolicController.text.trim();

    final (Color color, IconData icon, String label, String detail) = switch (cat) {
      _BpCategory.crisis  => (const Color(0xFF7F1D1D), Icons.emergency,          'Hypertensive Crisis',          'Your reading is critically high. Seek emergency medical care immediately. Do not wait — call 911 or go to the nearest emergency room.'),
      _BpCategory.stage2  => (const Color(0xFFEF4444), Icons.warning_rounded,     'High Blood Pressure — Stage 2','Systolic ≥ 140 or Diastolic ≥ 90 mmHg. Consult your doctor as soon as possible. Medication and significant lifestyle changes are typically required.'),
      _BpCategory.stage1  => (const Color(0xFFF97316), Icons.warning_amber_rounded,'High Blood Pressure — Stage 1','Systolic 130–139 or Diastolic 80–89 mmHg. Discuss with your doctor. Reduce sodium, exercise regularly, limit alcohol, and manage stress.'),
      _BpCategory.elevated=> (const Color(0xFFEAB308), Icons.trending_up,          'Elevated Blood Pressure',      'Systolic 120–129 and Diastolic < 80 mmHg. No medication needed yet, but adopt heart-healthy habits: reduce salt, increase physical activity, and maintain a healthy weight.'),
      _BpCategory.normal  => (const Color(0xFF22C55E), Icons.check_circle_outline, 'Normal Blood Pressure',        'Systolic < 120 and Diastolic < 80 mmHg. Great work! Keep up healthy habits — regular exercise, balanced diet, and stress management.'),
      _BpCategory.low     => (const Color(0xFF3B82F6), Icons.arrow_downward,       'Low Blood Pressure',           'Systolic < 90 or Diastolic < 60 mmHg. Consult your doctor if you have dizziness, fainting, or fatigue. Stay hydrated and rise slowly from seated or lying positions.'),
      _BpCategory.unknown => (const Color(0xFF6B7280), Icons.info_outline,         'Blood Pressure Guide',         'Normal: < 120/80. Elevated: 120–129 systolic. High Stage 1: 130–139/80–89. High Stage 2: ≥ 140/90. Low: < 90/60. Enter your reading above for a personalised assessment.'),
    };

    final learnMoreUrl = switch (cat) {
      _BpCategory.low                             => 'https://medlineplus.gov/lowbloodpressure.html',
      _BpCategory.normal                          => 'https://medlineplus.gov/vitalsigns.html',
      _BpCategory.crisis || _BpCategory.stage2 ||
      _BpCategory.stage1 || _BpCategory.elevated  => 'https://medlineplus.gov/highbloodpressure.html',
      _                                           => 'https://medlineplus.gov/bloodpressure.html',
    };

    final learnMoreLabel = switch (cat) {
      _BpCategory.low                             => 'Learn more about low blood pressure — MedlinePlus',
      _BpCategory.normal                          => 'Learn more about vital signs — MedlinePlus',
      _BpCategory.crisis || _BpCategory.stage2 ||
      _BpCategory.stage1 || _BpCategory.elevated  => 'Learn more about high blood pressure — MedlinePlus',
      _                                           => 'Learn more about blood pressure — MedlinePlus',
    };

    _showVitalInfoSheet(
      context,
      color: color,
      icon: icon,
      label: label,
      reading: (sys.isNotEmpty || dia.isNotEmpty) ? '${sys.isEmpty ? '?' : sys} / ${dia.isEmpty ? '?' : dia} mmHg' : null,
      detail: detail,
      learnMoreUrl: learnMoreUrl,
      learnMoreLabel: learnMoreLabel,
    );
  }

  // ── Sugar recommendation ──────────────────────────────────────────────────

  _SugarCategory _classifySugar() {
    final raw = double.tryParse(_sugarController.text.trim());
    if (raw == null) return _SugarCategory.unknown;
    final mgdl = _sugarUnit == 'mmol/L' ? raw * 18.0182 : raw;
    if (mgdl < 70)  return _SugarCategory.low;
    if (mgdl < 100) return _SugarCategory.normal;
    if (mgdl < 126) return _SugarCategory.preDiabetes;
    return _SugarCategory.diabetic;
  }

  void _showSugarRecommendation(BuildContext context) {
    final cat = _classifySugar();
    final val = _sugarController.text.trim();

    final (Color color, IconData icon, String label, String detail) = switch (cat) {
      _SugarCategory.low        => (const Color(0xFF3B82F6), Icons.arrow_downward,       'Low Blood Sugar (Hypoglycemia)', 'Below 70 mg/dL. Eat 15–20 g of fast-acting carbs (fruit juice, glucose tablets). Recheck in 15 minutes. Seek care if it does not recover.'),
      _SugarCategory.normal     => (const Color(0xFF22C55E), Icons.check_circle_outline, 'Normal Fasting Glucose',         'Fasting glucose 70–99 mg/dL. Excellent! Maintain a balanced diet low in refined carbs, stay active, and keep a healthy weight.'),
      _SugarCategory.preDiabetes=> (const Color(0xFFEAB308), Icons.trending_up,          'Pre-Diabetes Range',             'Fasting glucose 100–125 mg/dL. You are at risk. Losing 5–7% body weight, 150 min/week of moderate exercise, and cutting sugary drinks can often reverse this.'),
      _SugarCategory.diabetic   => (const Color(0xFFEF4444), Icons.warning_rounded,       'Diabetic Range',                 'Fasting glucose ≥ 126 mg/dL. Consult your doctor. Medication, diet change, regular monitoring, and exercise are key to managing blood sugar.'),
      _SugarCategory.unknown    => (const Color(0xFF6B7280), Icons.info_outline,          'Blood Sugar Guide',              'Fasting normal: 70–99 mg/dL. Pre-diabetes: 100–125. Diabetic: ≥ 126. Low (hypoglycemia): < 70. Enter your reading above for a personalised assessment.'),
    };

    _showVitalInfoSheet(
      context,
      color: color,
      icon: icon,
      label: label,
      reading: val.isNotEmpty ? '$val $_sugarUnit (fasting)' : null,
      detail: detail,
      learnMoreUrl: 'https://medlineplus.gov/bloodsugar.html',
      learnMoreLabel: 'Learn more about blood sugar — MedlinePlus',
    );
  }

  // ── Cholesterol recommendation ────────────────────────────────────────────

  _CholesterolCategory _classifyCholesterol() {
    final raw = double.tryParse(_cholesterolController.text.trim());
    if (raw == null) return _CholesterolCategory.unknown;
    final mgdl = _cholesterolUnit == 'mmol/L' ? raw * 38.67 : raw;
    if (mgdl < 200) return _CholesterolCategory.optimal;
    if (mgdl < 240) return _CholesterolCategory.borderline;
    return _CholesterolCategory.high;
  }

  void _showCholesterolRecommendation(BuildContext context) {
    final cat = _classifyCholesterol();
    final val = _cholesterolController.text.trim();

    final (Color color, IconData icon, String label, String detail) = switch (cat) {
      _CholesterolCategory.optimal   => (const Color(0xFF22C55E), Icons.check_circle_outline, 'Optimal Cholesterol',          'Total cholesterol < 200 mg/dL. Well done! Eat more fibre, healthy fats (avocado, nuts, olive oil), and stay physically active to keep it this way.'),
      _CholesterolCategory.borderline=> (const Color(0xFFEAB308), Icons.trending_up,          'Borderline High Cholesterol',  'Total cholesterol 200–239 mg/dL. Make dietary changes: reduce saturated and trans fats, increase soluble fibre, and exercise 30 min/day. Recheck in 6 months.'),
      _CholesterolCategory.high      => (const Color(0xFFEF4444), Icons.warning_rounded,       'High Cholesterol',             'Total cholesterol ≥ 240 mg/dL. Consult your doctor. Statin therapy may be needed alongside diet change and exercise to lower cardiovascular risk.'),
      _CholesterolCategory.unknown   => (const Color(0xFF6B7280), Icons.info_outline,          'Cholesterol Guide',            'Optimal total cholesterol: < 200 mg/dL. Borderline high: 200–239. High: ≥ 240. LDL goal: < 100. HDL: > 60 is protective. Enter your reading for a personalised assessment.'),
    };

    _showVitalInfoSheet(
      context,
      color: color,
      icon: icon,
      label: label,
      reading: val.isNotEmpty ? '$val $_cholesterolUnit (total)' : null,
      detail: detail,
      learnMoreUrl: 'https://medlineplus.gov/cholesterol.html',
      learnMoreLabel: 'Learn more about cholesterol — MedlinePlus',
    );
  }

  // ── Weight recommendation ─────────────────────────────────────────────────

  _WeightCategory _classifyWeight() {
    final raw = double.tryParse(_weightController.text.trim());
    if (raw == null) return _WeightCategory.unknown;
    // Normalise to lbs for thresholds
    final lbs = _weightUnit == 'kg' ? raw * 2.20462 : raw;
    if (lbs < 110) return _WeightCategory.low;
    if (lbs <= 174) return _WeightCategory.normal;
    if (lbs <= 239) return _WeightCategory.high;
    return _WeightCategory.veryHigh;
  }

  void _showWeightRecommendation(BuildContext context) {
    final cat = _classifyWeight();
    final val = _weightController.text.trim();

    final (Color color, IconData icon, String label, String detail) = switch (cat) {
      _WeightCategory.low      => (const Color(0xFF3B82F6), Icons.arrow_downward,       'Low Weight',           'Your weight appears below average. If unintentional, consult your doctor to rule out nutritional deficiency or an underlying condition. Eat nutrient-dense foods and strength-train.'),
      _WeightCategory.normal   => (const Color(0xFF22C55E), Icons.check_circle_outline, 'Healthy Weight Range', 'Your weight is within a typical healthy range. Maintain it with regular exercise, a balanced diet, and consistent sleep. Track trends rather than daily fluctuations.'),
      _WeightCategory.high     => (const Color(0xFFEAB308), Icons.trending_up,          'Above Average Weight', 'Your weight is above the average healthy range. Aim for 30 min of moderate exercise 5 days a week, reduce processed food and sugary drinks, and track portion sizes.'),
      _WeightCategory.veryHigh => (const Color(0xFFEF4444), Icons.warning_rounded,      'High Weight',          'Your weight may increase health risks such as diabetes, high BP, and joint problems. Consult your doctor for a personalised plan. Small sustainable changes make a big difference.'),
      _WeightCategory.unknown  => (const Color(0xFF3B82F6), Icons.scale_outlined,       'Healthy Weight Tips',  'BMI = weight (kg) ÷ height (m)². Healthy BMI: 18.5–24.9. Overweight: 25–29.9. Obese: ≥ 30.\n\nWeigh yourself at the same time each day (morning, after bathroom). Aim for gradual change of 0.5–1 lb/week.'),
    };

    _showVitalInfoSheet(
      context,
      color: color,
      icon: icon,
      label: label,
      reading: val.isNotEmpty ? '$val $_weightUnit' : null,
      detail: '${detail}\n\nNote: These ranges are based on average adult weight. For a precise assessment, calculate your BMI using your height.',
      learnMoreUrl: 'https://medlineplus.gov/weightcontrol.html',
      learnMoreLabel: 'Learn more about healthy weight — MedlinePlus',
    );
  }

  List<Widget> _buildDailyFields(BuildContext context) => [
    _SectionCard(
      title: 'Blood Pressure',
      icon: Icons.favorite_outlined,
      iconColor: const Color(0xFFEF4444),
      trailing: IconButton(
        icon: Icon(Icons.lightbulb, size: 18, color: _bpBulbColor),
        tooltip: _bpTooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: () => _showBpRecommendation(context),
      ),
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
      trailing: IconButton(
        icon: Icon(Icons.lightbulb, size: 18, color: _sugarBulbColor),
        tooltip: _sugarTooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: () => _showSugarRecommendation(context),
      ),
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
      trailing: IconButton(
        icon: Icon(Icons.lightbulb, size: 18, color: _cholesterolBulbColor),
        tooltip: _cholesterolTooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: () => _showCholesterolRecommendation(context),
      ),
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
      trailing: IconButton(
        icon: Icon(Icons.lightbulb, size: 18, color: _weightBulbColor),
        tooltip: _weightTooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: () => _showWeightRecommendation(context),
      ),
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

  Color get _riskBulbColor => switch (_riskLevel) {
    'High'   => const Color(0xFFEF4444),
    'Medium' => const Color(0xFFF97316),
    _        => const Color(0xFF22C55E),
  };

  Widget _buildRiskSection() {
    return _SectionCard(
      title: 'Overall Risk Level',
      icon: Icons.shield_outlined,
      iconColor: const Color(0xFF8B5CF6),
      trailing: IconButton(
        icon: Icon(Icons.lightbulb, size: 18, color: _riskBulbColor),
        tooltip: '$_riskLevel Risk — learn more',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: () => launchUrl(
          Uri.parse('https://medlineplus.gov'),
          mode: LaunchMode.externalApplication,
        ),
      ),
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

// ── BP category enum ──────────────────────────────────────────────────────────

enum _BpCategory { unknown, low, normal, elevated, stage1, stage2, crisis }
enum _SugarCategory { unknown, low, normal, preDiabetes, diabetic }
enum _CholesterolCategory { unknown, optimal, borderline, high }
enum _WeightCategory { unknown, low, normal, high, veryHigh }

// ── Section card ─────────────────────────────────────────────────────────────

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
