import 'package:flutter/material.dart';
import '../models/vital.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../screens/add_vital_screen.dart';

class VitalsTab extends StatefulWidget {
  const VitalsTab({super.key});

  @override
  State<VitalsTab> createState() => VitalsTabState();
}

class VitalsTabState extends State<VitalsTab> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  List<Vital> _vitals = [];
  bool _loading = true;
  String? _sex;

  bool get _isFemale => _sex == 'Female';

  List<String> get _tabs => _isFemale
      ? ['Daily', 'Monthly', 'Misc']
      : ['Daily', 'Misc'];

  List<String> get _categories => _isFemale
      ? ['daily', 'monthly', 'open']
      : ['daily', 'open'];

  String get _currentCategory =>
      _tabController != null ? _categories[_tabController!.index] : 'daily';

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
    await Future.wait([
      AuthService.getSex().then((v) { sex = v; }).catchError((_) {}),
      StorageService.getVitals().then((v) { list = v; }).catchError((_) {}),
    ]);

    final cutoff = DateTime.now().subtract(const Duration(days: 5));

    // Auto-delete only daily vitals older than 5 days
    for (final v in list.where((v) => v.category == 'daily' && v.recordedAt.isBefore(cutoff))) {
      await StorageService.deleteVital(v.id);
    }

    final kept = list
        .where((v) => v.category != 'daily' || !v.recordedAt.isBefore(cutoff))
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    if (!mounted) return;

    final tabCount = sex == 'Female' ? 3 : 2;
    if (_tabController == null || _tabController!.length != tabCount) {
      _tabController?.dispose();
      _tabController = TabController(length: tabCount, vsync: this);
    }

    setState(() { _sex = sex; _vitals = kept; _loading = false; });
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
              if (_isFemale)
                _VitalsListView(
                  vitals: _filtered('monthly'),
                  category: 'monthly',
                  onTap: _open,
                  onRefresh: _load,
                ),
              _VitalsListView(
                vitals: _filtered('open'),
                category: 'open',
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
  final Future<void> Function(Vital) onTap;
  final Future<void> Function() onRefresh;

  const _VitalsListView({
    required this.vitals,
    required this.category,
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
            'monthly' => _MonthlyCard(vital: v, onTap: () => onTap(v)),
            'open'    => _OpenCard(vital: v, onTap: () => onTap(v)),
            _         => _DailyCard(vital: v, onTap: () => onTap(v)),
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

  Color get _riskColor {
    switch (vital.riskLevel) {
      case 'High': return const Color(0xFFEF4444);
      case 'Medium': return const Color(0xFFF97316);
      default: return const Color(0xFF22C55E);
    }
  }

  Color get _riskBg {
    switch (vital.riskLevel) {
      case 'High': return const Color(0xFFFEF2F2);
      case 'Medium': return const Color(0xFFFFF7ED);
      default: return const Color(0xFFF0FDF4);
    }
  }

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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: _riskBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _riskColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 7, color: _riskColor),
                    const SizedBox(width: 4),
                    Text('${vital.riskLevel} Risk',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _riskColor,
                        )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniVital(icon: Icons.favorite_outlined,   value: vital.bpDisplay,          color: const Color(0xFFEF4444), bulbColor: _bpBulbColor(vital.bpSystolic, vital.bpDiastolic)),
              const SizedBox(width: 8),
              _MiniVital(icon: Icons.water_drop_outlined, value: vital.sugarDisplay,       color: const Color(0xFFF97316), bulbColor: _sugarBulbColor(vital.sugarLevel, vital.sugarUnit)),
              const SizedBox(width: 8),
              _MiniVital(icon: Icons.scale_outlined,      value: vital.weightDisplay,      color: const Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              _MiniVital(icon: Icons.biotech_outlined,    value: vital.cholesterolDisplay, color: const Color(0xFF8B5CF6), bulbColor: _cholesterolBulbColor(vital.cholesterol, vital.cholesterolUnit)),
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

// ── Monthly card (Period / Mammogram) ────────────────────────────────────────

class _MonthlyCard extends StatelessWidget {
  final Vital vital;
  final VoidCallback onTap;
  const _MonthlyCard({required this.vital, required this.onTap});

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
          Text(_fmtDate(vital.recordedAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 8),
          if (vital.periodDate != null)
            _MonthlyRow(
              icon: Icons.calendar_month_outlined,
              label: 'Last Period',
              value: _fmtDate(vital.periodDate!),
              color: const Color(0xFF7A2420),
            ),
          if (vital.mammogramDate != null) ...[
            if (vital.periodDate != null) const SizedBox(height: 6),
            _MonthlyRow(
              icon: Icons.medical_information_outlined,
              label: 'Mammogram',
              value: _fmtDate(vital.mammogramDate!),
              color: const Color(0xFF8B5CF6),
            ),
          ],
          if (vital.periodDate == null && vital.mammogramDate == null)
            Text('No dates recorded',
                style: TextStyle(fontSize: 13, color: Colors.grey[400])),
          if (vital.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
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

class _MonthlyRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MonthlyRow({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

// ── Open card (custom event) ─────────────────────────────────────────────────

class _OpenCard extends StatelessWidget {
  final Vital vital;
  final VoidCallback onTap;
  const _OpenCard({required this.vital, required this.onTap});

  String _fmtDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final name = vital.eventName.isNotEmpty ? vital.eventName : 'Health Event';
    return _BaseCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.event_note, color: Color(0xFF3B82F6), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF635A5A),
                          )),
                    ),
                    Text(_fmtDate(vital.recordedAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
                if (vital.notes.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(vital.notes,
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
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
  const _MiniVital({required this.icon, required this.value, required this.color, this.bulbColor});

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
        child: Row(
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
      ),
    );
  }
}
