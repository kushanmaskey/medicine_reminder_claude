import 'package:flutter/material.dart';
import '../models/doctor.dart';
import '../models/vital.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../screens/add_vital_screen.dart';

class VitalsTab extends StatefulWidget {
  final VoidCallback? onDoctorAdded;
  const VitalsTab({super.key, this.onDoctorAdded});

  @override
  State<VitalsTab> createState() => VitalsTabState();
}

class VitalsTabState extends State<VitalsTab> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  List<Vital> _vitals = [];
  Map<String, String> _doctorNames = {};
  bool _loading = true;
  String? _sex;

  List<String> get _tabs => ['Daily', 'Misc'];

  String get _currentCategory =>
      _tabController != null && _tabController!.index == 1 ? 'open' : 'daily';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);

    String? sex;
    List<Vital> list = [];
    List<Doctor> doctors = [];
    await Future.wait([
      AuthService.getSex().then((v) { sex = v; }).catchError((_) {}),
      StorageService.getVitals().then((v) { list = v; }).catchError((_) {}),
      StorageService.getDoctors().then((v) { doctors = v; }).catchError((_) {}),
    ]);

    final kept = List<Vital>.from(list)
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    if (!mounted) return;

    if (_tabController == null || _tabController!.length != 2) {
      _tabController?.dispose();
      _tabController = TabController(length: 2, vsync: this);
    }

    setState(() {
      _sex = sex;
      _vitals = kept;
      _doctorNames = {for (final d in doctors) d.id: d.fullName};
      _loading = false;
    });
  }

  void reload() => _load();

  Future<bool> openAdd() async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => AddVitalScreen(category: _currentCategory),
      ),
    );
    if (result == true || result == 'deleted') {
      _load();
      return true;
    }
    return false;
  }

  Future<void> _open(Vital v) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => AddVitalScreen(existing: v, category: v.category)),
    );
    if (result == true || result == 'deleted') _load();
  }

  List<Vital> _filtered(String category) =>
      _vitals.where((v) => v.category == category).toList();

  List<Vital> _filteredMisc() =>
      _vitals.where((v) => v.category == 'open' || v.category == 'monthly').toList();

  @override
  Widget build(BuildContext context) {
    if (_loading || _tabController == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController!,
            children: [
              _VitalsListView(
                vitals: _filtered('daily'),
                category: 'daily',
                onTap: _open,
                onRefresh: _load,
              ),
              _VitalsListView(
                vitals: _filteredMisc(),
                category: 'open',
                isFemale: _sex == 'Female',
                doctorNames: _doctorNames,
                onTap: _open,
                onRefresh: _load,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TabBar(
        controller: _tabController!,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF501513),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        indicator: BoxDecoration(
          color: const Color(0xFF501513),
          borderRadius: BorderRadius.circular(20),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: [
          for (final label in _tabs)
            Tab(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(label),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Per-tab list view ────────────────────────────────────────────────────────

class _VitalsListView extends StatelessWidget {
  final List<Vital> vitals;
  final String category;
  final bool isFemale;
  final Map<String, String> doctorNames;
  final Future<void> Function(Vital) onTap;
  final Future<void> Function() onRefresh;

  const _VitalsListView({
    required this.vitals,
    required this.category,
    this.isFemale = false,
    this.doctorNames = const {},
    required this.onTap,
    required this.onRefresh,
  });

  String get _emptyTitle {
    switch (category) {
      case 'monthly': return 'No Monthly Records';
      case 'open': return 'No Open Events';
      default: return 'No Daily Vitals';
    }
  }

  String get _emptySubtitle {
    switch (category) {
      case 'monthly': return 'Tap + to log period, mammogram, or other monthly data';
      case 'open': return 'Tap + to log a procedure or one-time health event';
      default: return 'Tap + to log BP, weight, sugar, or cholesterol';
    }
  }

  IconData get _emptyIcon {
    switch (category) {
      case 'monthly': return Icons.calendar_month_outlined;
      case 'open': return Icons.event_note_outlined;
      default: return Icons.monitor_heart_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (vitals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_emptyIcon, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(_emptyTitle,
                style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_emptySubtitle,
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: vitals.length,
        itemBuilder: (ctx, i) {
          final v = vitals[i];
          return switch (category) {
            'open' => _OpenCard(vital: v, isFemale: isFemale, doctorNames: doctorNames, onTap: () => onTap(v)),
            _      => _DailyCard(vital: v, onTap: () => onTap(v)),
          };
        },
      ),
    );
  }
}

// ── Vital classification helpers ──────────────────────────────────────────────

Color? _bpBulbColor(int? sys, int? dia) {
  if (sys == null && dia == null) return null;
  if ((sys != null && sys > 180) || (dia != null && dia > 120)) return const Color(0xFF7F1D1D);
  if ((sys != null && sys >= 140) || (dia != null && dia >= 90))  return const Color(0xFFEF4444);
  if ((sys != null && sys >= 130) || (dia != null && dia >= 80))  return const Color(0xFFF97316);
  if (sys != null && sys >= 120 && (dia == null || dia < 80))     return const Color(0xFFEAB308);
  if ((sys != null && sys < 90)  || (dia != null && dia < 60))    return const Color(0xFF3B82F6);
  return const Color(0xFF22C55E);
}

Color? _sugarBulbColor(double? sugar, String unit) {
  if (sugar == null) return null;
  final mg = unit == 'mmol/L' ? sugar * 18.0182 : sugar;
  if (mg < 70)  return const Color(0xFF3B82F6);
  if (mg < 100) return const Color(0xFF22C55E);
  if (mg < 126) return const Color(0xFFEAB308);
  return const Color(0xFFEF4444);
}

Color? _cholesterolBulbColor(double? chol, String unit) {
  if (chol == null) return null;
  final mg = unit == 'mmol/L' ? chol * 38.67 : chol;
  if (mg < 200) return const Color(0xFF22C55E);
  if (mg < 240) return const Color(0xFFEAB308);
  return const Color(0xFFEF4444);
}

// ── Daily card (BP / Sugar / Weight / Cholesterol) ───────────────────────────

class _DailyCard extends StatelessWidget {
  final Vital vital;
  final VoidCallback onTap;
  const _DailyCard({required this.vital, required this.onTap});

  String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.monitor_heart,
                    color: Color(0xFF501513), size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _formatDate(vital.recordedAt),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF635A5A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniVital(
                icon: Icons.favorite_outlined,
                value: vital.bpDisplay,
                color: const Color(0xFFEF4444),
                count: vital.bpReadings.length,
                bulbColor: vital.hasBP
                    ? _bpBulbColor(vital.bpReadings.last.systolic, vital.bpReadings.last.diastolic)
                    : null,
              ),
              const SizedBox(width: 8),
              _MiniVital(
                icon: Icons.water_drop_outlined,
                value: vital.sugarDisplay,
                color: const Color(0xFFF97316),
                count: vital.sugarReadings.length,
                bulbColor: vital.hasSugar
                    ? _sugarBulbColor(vital.sugarReadings.last.value, vital.sugarUnit)
                    : null,
              ),
              const SizedBox(width: 8),
              _MiniVital(
                icon: Icons.scale_outlined,
                value: vital.weightDisplay,
                color: const Color(0xFF3B82F6),
                count: vital.weightReadings.length,
              ),
              const SizedBox(width: 8),
              _MiniVital(
                icon: Icons.biotech_outlined,
                value: vital.cholesterolDisplay,
                color: const Color(0xFF8B5CF6),
                count: vital.cholesterolReadings.length,
                bulbColor: vital.hasCholesterol
                    ? _cholesterolBulbColor(vital.cholesterolReadings.last.value, vital.cholesterolUnit)
                    : null,
              ),
            ],
          ),
          if (vital.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(vital.notes,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

// ── Misc card (Period / Mammogram / Colonoscopy / Event/Procedure) ────────────

class _OpenCard extends StatelessWidget {
  final Vital vital;
  final bool isFemale;
  final Map<String, String> doctorNames;
  final VoidCallback onTap;
  const _OpenCard({required this.vital, this.isFemale = false, this.doctorNames = const {}, required this.onTap});

  String _fmtDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ),
          const SizedBox(height: 8),
          if (vital.eventName.isNotEmpty)
            _ProcedureBlock(
              icon: Icons.event_note_outlined,
              color: const Color(0xFF3B82F6),
              label: vital.eventName,
              date: _fmtDate(vital.recordedAt),
              location: vital.location,
            ),
          if (isFemale && vital.periodDate != null)
            _ProcedureBlock(
              icon: Icons.calendar_month_outlined,
              color: const Color(0xFF7A2420),
              label: 'Period',
              date: _fmtDate(vital.periodDate!),
            ),
          if (isFemale && vital.mammogramDate != null)
            _ProcedureBlock(
              icon: Icons.medical_information_outlined,
              color: const Color(0xFF8B5CF6),
              label: 'Mammogram',
              date: _fmtDate(vital.mammogramDate!),
              location: vital.mammogramLocation,
            ),
          if (vital.colonoscopyDate != null)
            _ProcedureBlock(
              icon: Icons.biotech_outlined,
              color: const Color(0xFF0EA5E9),
              label: 'Colonoscopy',
              date: _fmtDate(vital.colonoscopyDate!),
              location: vital.colonoscopyLocation,
            ),
          if (vital.dentalDate != null)
            _ProcedureBlock(
              icon: Icons.health_and_safety_outlined,
              color: const Color(0xFF22C55E),
              label: 'Dental',
              date: _fmtDate(vital.dentalDate!),
              location: vital.dentalLocation,
            ),
          if (vital.eyeExamDate != null)
            _ProcedureBlock(
              icon: Icons.visibility_outlined,
              color: const Color(0xFF8B5CF6),
              label: 'Eye Exam',
              date: _fmtDate(vital.eyeExamDate!),
              location: vital.eyeExamLocation,
            ),
        ],
      ),
    );
  }
}

class _ProcedureBlock extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? date;
  final String location;

  const _ProcedureBlock({
    required this.icon,
    required this.color,
    required this.label,
    this.date,
    this.location = '',
  });

  @override
  Widget build(BuildContext context) {
    final parts = <String>[label];
    if (date != null) parts.add(date!);
    if (location.isNotEmpty) parts.add(location);

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              parts.join('  ·  '),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared base card ─────────────────────────────────────────────────────────

class _BaseCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _BaseCard({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ── Mini vital chip ───────────────────────────────────────────────────────────

class _MiniVital extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  final Color? bulbColor;
  final int count;
  const _MiniVital({
    required this.icon,
    required this.value,
    required this.color,
    this.bulbColor,
    this.count = 0,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != '—';
    final showBulb = bulbColor != null && hasValue;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: hasValue ? color : Colors.grey[400],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (showBulb) ...[
                  const SizedBox(width: 3),
                  Icon(Icons.lightbulb, size: 10, color: bulbColor),
                ],
              ],
            ),
            if (count > 1) ...[
              const SizedBox(height: 2),
              Text(
                '×$count',
                style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.6), fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
