import 'package:flutter/material.dart';
import '../models/vital.dart';
import '../services/storage_service.dart';
import 'add_vital_screen.dart';

class VitalDetailScreen extends StatefulWidget {
  final DateTime date;
  final String category;
  final bool isFemale;
  final Map<String, String> doctorNames;

  const VitalDetailScreen({
    super.key,
    required this.date,
    required this.category,
    this.isFemale = false,
    this.doctorNames = const {},
  });

  @override
  State<VitalDetailScreen> createState() => _VitalDetailScreenState();
}

class _VitalDetailScreenState extends State<VitalDetailScreen> {
  List<Vital> _entries = [];
  List<_FlatEntry> _flat = [];
  bool _loading = true;
  bool _changed = false;

  bool get _isDaily => widget.category == 'daily';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final all = await StorageService.getVitals();
    final dayEnd = widget.date.add(const Duration(days: 1));
    final entries = all.where((v) {
      final inDay = !v.recordedAt.isBefore(widget.date) && v.recordedAt.isBefore(dayEnd);
      if (!inDay) return false;
      return widget.category == 'daily'
          ? v.category == 'daily'
          : v.category == 'open' || v.category == 'monthly';
    }).toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    final flat = _buildFlat(entries);

    if (mounted) setState(() {
      _entries = entries;
      _flat = flat;
      _loading = false;
    });
  }

  static List<_FlatEntry> _buildFlat(List<Vital> vitals) {
    final flat = <_FlatEntry>[];
    for (final v in vitals) {
      for (final r in v.bpReadings) {
        flat.add(_FlatEntry(
          vital: v, time: r.time, type: 'bp',
          label: '${r.systolic}/${r.diastolic} mmHg',
          color: const Color(0xFFEF4444),
          icon: Icons.favorite_outlined,
        ));
      }
      for (final r in v.sugarReadings) {
        flat.add(_FlatEntry(
          vital: v, time: r.time, type: 'sugar',
          label: '${r.value.toStringAsFixed(1)} ${v.sugarUnit}',
          color: const Color(0xFFF97316),
          icon: Icons.water_drop_outlined,
        ));
      }
      for (final r in v.weightReadings) {
        flat.add(_FlatEntry(
          vital: v, time: r.time, type: 'weight',
          label: '${r.value.toStringAsFixed(1)} ${v.weightUnit}',
          color: const Color(0xFF3B82F6),
          icon: Icons.scale_outlined,
        ));
      }
      for (final r in v.cholesterolReadings) {
        flat.add(_FlatEntry(
          vital: v, time: r.time, type: 'cholesterol',
          label: '${r.value.toStringAsFixed(1)} ${v.cholesterolUnit}',
          color: const Color(0xFF8B5CF6),
          icon: Icons.biotech_outlined,
        ));
      }
    }
    return flat;
  }

  static const _typeOrder = [
    ('bp',          'Blood Pressure', Icons.favorite_outlined,   Color(0xFFEF4444)),
    ('sugar',       'Sugar Level',    Icons.water_drop_outlined, Color(0xFFF97316)),
    ('weight',      'Weight',         Icons.scale_outlined,      Color(0xFF3B82F6)),
    ('cholesterol', 'Cholesterol',    Icons.biotech_outlined,    Color(0xFF8B5CF6)),
  ];

  List<Widget> _buildGroupedDailyWidgets() {
    final widgets = <Widget>[];
    for (final (type, title, icon, color) in _typeOrder) {
      final group = _flat.where((e) => e.type == type).toList()
        ..sort((a, b) => b.time.compareTo(a.time)); // desc — newest first
      if (group.isEmpty) continue;

      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8, left: 2, right: 2),
        child: Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey[500],
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ));

      widgets.add(Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: group.asMap().entries.map((e) {
            final isLast = e.key == group.length - 1;
            return _FlatEntryRow(
              entry: e.value,
              time: _formatTime(e.value.time),
              isLast: isLast,
            );
          }).toList(),
        ),
      ));

      widgets.add(const SizedBox(height: 16));
    }
    return widgets;
  }

  Future<void> _edit(Vital v) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => AddVitalScreen(
          existing: v,
          category: v.category,
          sameDayHistory: v.category == 'daily'
              ? _entries.where((e) => e.id != v.id).toList()
              : const [],
        ),
      ),
    );
    if (result == true || result == 'deleted') {
      _changed = true;
      await _load();
      final empty = _isDaily ? _flat.isEmpty : _entries.isEmpty;
      if (empty && mounted) Navigator.pop(context, 'deleted');
    }
  }

  Future<void> _addEntry() async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => AddVitalScreen(
          category: widget.category == 'daily' ? 'daily' : 'open',
          initialDate: widget.date,
          sameDayHistory: widget.category == 'daily' ? _entries : const [],
        ),
      ),
    );
    if (result == true) {
      _changed = true;
      await _load();
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '${h.toString().padLeft(2, '0')}:$m $ampm';
  }

  String _dayLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (widget.date == today) return 'Today';
    if (widget.date == yesterday) return 'Yesterday';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[widget.date.month - 1]} ${widget.date.day}, ${widget.date.year}';
  }

  bool get _isEmpty => _isDaily ? _flat.isEmpty : _entries.isEmpty;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: BackButton(
            color: const Color(0xFF484141),
            onPressed: () => Navigator.pop(context, _changed),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isDaily ? 'Daily Vitals' : 'Misc Records',
                style: const TextStyle(
                  color: Color(0xFF484141),
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              Text(
                _dayLabel(),
                style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w400),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _addEntry,
              tooltip: 'Add / Edit',
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF501513), size: 22),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _isEmpty
                ? Center(
                    child: Text(
                      'No entries',
                      style: TextStyle(color: Colors.grey[500], fontSize: 15),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: _isDaily
                        ? _buildGroupedDailyWidgets()
                        : [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade100),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: _entries.asMap().entries.map((e) {
                                  final isLast = e.key == _entries.length - 1;
                                  return _MiscEntryRow(
                                    vital: e.value,
                                    time: _formatTime(e.value.recordedAt),
                                    isFemale: widget.isFemale,
                                    isLast: isLast,
                                    onTap: () => _edit(e.value),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                  ),
      ),
    );
  }
}

// ── Flat reading data model ────────────────────────────────────────────────────

class _FlatEntry {
  final Vital vital;
  final DateTime time;
  final String label;
  final Color color;
  final IconData icon;
  final String type; // 'bp' | 'sugar' | 'weight' | 'cholesterol'

  _FlatEntry({
    required this.vital,
    required this.time,
    required this.label,
    required this.color,
    required this.icon,
    required this.type,
  });
}

// ── Flat reading row (one row per individual reading) ─────────────────────────

class _FlatEntryRow extends StatelessWidget {
  final _FlatEntry entry;
  final String time;
  final bool isLast;

  const _FlatEntryRow({
    required this.entry,
    required this.time,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 68,
                child: Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: entry.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: entry.color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(entry.icon, size: 13, color: entry.color),
                    const SizedBox(width: 5),
                    Text(
                      entry.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: entry.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, indent: 14, endIndent: 14, color: Colors.grey.shade100),
      ],
    );
  }
}

// ── Misc entry row ────────────────────────────────────────────────────────────

class _MiscEntryRow extends StatelessWidget {
  final Vital vital;
  final String time;
  final bool isFemale;
  final bool isLast;
  final VoidCallback onTap;

  const _MiscEntryRow({
    required this.vital,
    required this.time,
    required this.isFemale,
    required this.isLast,
    required this.onTap,
  });

  List<String> _labels() {
    final labels = <String>[];
    if (vital.eventName.isNotEmpty) labels.add(vital.eventName);
    if (vital.colonoscopyDate != null) labels.add('Colonoscopy');
    if (vital.dentalDate != null) labels.add('Dental');
    if (vital.eyeExamDate != null) labels.add('Eye Exam');
    if (isFemale && vital.periodDate != null) labels.add('Period');
    if (isFemale && vital.mammogramDate != null) labels.add('Mammogram');
    return labels;
  }

  @override
  Widget build(BuildContext context) {
    final labels = _labels();
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: isLast
                ? const BorderRadius.vertical(bottom: Radius.circular(16))
                : BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 68,
                    child: Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: labels.isEmpty
                          ? [Text('—', style: TextStyle(color: Colors.grey[400], fontSize: 12))]
                          : labels.map((l) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
                                ),
                                child: Text(
                                  l,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF3B82F6),
                                  ),
                                ),
                              )).toList(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        ),
        if (!isLast) Divider(height: 1, indent: 14, endIndent: 14, color: Colors.grey.shade100),
      ],
    );
  }
}
