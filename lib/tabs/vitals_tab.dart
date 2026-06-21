import 'package:flutter/material.dart';
import '../models/doctor.dart';
import '../models/vital.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../screens/add_vital_screen.dart';
import '../screens/vital_detail_screen.dart';

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

  List<Vital> _sameDayHistory(DateTime date, {String? excludeId}) {
    return _vitals.where((v) {
      if (v.category != 'daily') return false;
      if (excludeId != null && v.id == excludeId) return false;
      final d = v.recordedAt;
      return d.year == date.year && d.month == date.month && d.day == date.day;
    }).toList();
  }

  Future<bool> openAdd() async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => AddVitalScreen(
          category: _currentCategory,
          sameDayHistory: _currentCategory == 'daily' ? _sameDayHistory(DateTime.now()) : const [],
        ),
      ),
    );
    if (result == true || result == 'deleted') {
      _load();
      return true;
    }
    return false;
  }

  Future<void> _openDetail(_VitalDayGroup group, String category) async {
    await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => VitalDetailScreen(
          date: group.date,
          category: category,
          isFemale: _sex == 'Female',
          doctorNames: _doctorNames,
        ),
      ),
    );
    _load();
  }

  static List<_VitalDayGroup> _groupByDay(List<Vital> vitals) {
    final dayMap = <String, List<Vital>>{};
    final dayDates = <String, DateTime>{};

    for (final v in vitals) {
      final dt = v.recordedAt;
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      dayMap.putIfAbsent(key, () => []).add(v);
      dayDates.putIfAbsent(key, () => DateTime(dt.year, dt.month, dt.day));
    }

    final groups = <_VitalDayGroup>[];
    for (final key in dayMap.keys) {
      final sorted = List<Vital>.from(dayMap[key]!)
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
      groups.add(_VitalDayGroup(date: dayDates[key]!, vitals: sorted));
    }
    return groups..sort((a, b) => b.date.compareTo(a.date));
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
                groups: _groupByDay(_filtered('daily')),
                category: 'daily',
                onTapGroup: (g) => _openDetail(g, 'daily'),
                onRefresh: _load,
              ),
              _VitalsListView(
                groups: _groupByDay(_filteredMisc()),
                category: 'open',
                isFemale: _sex == 'Female',
                doctorNames: _doctorNames,
                onTapGroup: (g) => _openDetail(g, 'open'),
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

// ── Day group data model ──────────────────────────────────────────────────────

class _VitalDayGroup {
  final DateTime date;
  final List<Vital> vitals; // sorted oldest-first
  _VitalDayGroup({required this.date, required this.vitals});
  int get count => vitals.length;
}

// ── Per-tab list view ────────────────────────────────────────────────────────

class _VitalsListView extends StatelessWidget {
  final List<_VitalDayGroup> groups;
  final String category;
  final bool isFemale;
  final Map<String, String> doctorNames;
  final void Function(_VitalDayGroup) onTapGroup;
  final Future<void> Function() onRefresh;

  const _VitalsListView({
    required this.groups,
    required this.category,
    this.isFemale = false,
    this.doctorNames = const {},
    required this.onTapGroup,
    required this.onRefresh,
  });

  String get _emptyTitle {
    switch (category) {
      case 'monthly': return 'No Monthly Records';
      case 'open': return 'No Misc Records';
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
    if (groups.isEmpty) {
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
        itemCount: groups.length,
        itemBuilder: (ctx, i) => _VitalDayCard(
          group: groups[i],
          category: category,
          isFemale: isFemale,
          onTap: () => onTapGroup(groups[i]),
        ),
      ),
    );
  }
}

// ── Day card ──────────────────────────────────────────────────────────────────

class _VitalDayCard extends StatelessWidget {
  final _VitalDayGroup group;
  final String category;
  final bool isFemale;
  final VoidCallback onTap;

  const _VitalDayCard({
    required this.group,
    required this.category,
    this.isFemale = false,
    required this.onTap,
  });

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

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
                      child: Icon(
                        category == 'daily'
                            ? Icons.monitor_heart
                            : Icons.event_note_outlined,
                        color: const Color(0xFF501513),
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _dayLabel(group.date),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF635A5A),
                        ),
                      ),
                    ),
                    if (group.count > 1) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF501513).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${group.count} entries',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF501513),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                  ],
                ),
                const SizedBox(height: 10),
                if (category == 'daily') _buildDailyContent()
                else _buildMiscContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyContent() {
    final allBp    = group.vitals.expand((v) => v.bpReadings).toList();
    final allSugar = group.vitals.expand((v) => v.sugarReadings).toList();
    final allWeight = group.vitals.expand((v) => v.weightReadings).toList();
    final allChol  = group.vitals.expand((v) => v.cholesterolReadings).toList();
    final last = group.vitals.last;

    final bpVal    = allBp.isNotEmpty ? '${allBp.last.systolic}/${allBp.last.diastolic} mmHg' : '—';
    final sugarVal = allSugar.isNotEmpty ? '${allSugar.last.value.toStringAsFixed(1)} ${last.sugarUnit}' : '—';
    final weightVal = allWeight.isNotEmpty ? '${allWeight.last.value.toStringAsFixed(1)} ${last.weightUnit}' : '—';
    final cholVal  = allChol.isNotEmpty ? '${allChol.last.value.toStringAsFixed(1)} ${last.cholesterolUnit}' : '—';

    Color? bpBulb = allBp.isNotEmpty
        ? _bpBulbColor(allBp.last.systolic, allBp.last.diastolic) : null;
    Color? sugarBulb = allSugar.isNotEmpty
        ? _sugarBulbColor(allSugar.last.value, last.sugarUnit) : null;
    Color? cholBulb = allChol.isNotEmpty
        ? _cholesterolBulbColor(allChol.last.value, last.cholesterolUnit) : null;

    return Row(
      children: [
        _MiniVital(icon: Icons.favorite_outlined, value: bpVal, color: const Color(0xFFEF4444), count: allBp.length, bulbColor: bpBulb),
        const SizedBox(width: 8),
        _MiniVital(icon: Icons.water_drop_outlined, value: sugarVal, color: const Color(0xFFF97316), count: allSugar.length, bulbColor: sugarBulb),
        const SizedBox(width: 8),
        _MiniVital(icon: Icons.scale_outlined, value: weightVal, color: const Color(0xFF3B82F6), count: allWeight.length),
        const SizedBox(width: 8),
        _MiniVital(icon: Icons.biotech_outlined, value: cholVal, color: const Color(0xFF8B5CF6), count: allChol.length, bulbColor: cholBulb),
      ],
    );
  }

  Widget _buildMiscContent() {
    final labels = <String>[];
    for (final v in group.vitals) {
      if (v.eventName.isNotEmpty) labels.add(v.eventName);
      if (v.colonoscopyDate != null) labels.add('Colonoscopy');
      if (v.dentalDate != null) labels.add('Dental');
      if (v.eyeExamDate != null) labels.add('Eye Exam');
      if (isFemale && v.periodDate != null) labels.add('Period');
      if (isFemale && v.mammogramDate != null) labels.add('Mammogram');
    }
    if (labels.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: labels.take(5).map((l) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
        ),
        child: Text(l, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6))),
      )).toList(),
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
