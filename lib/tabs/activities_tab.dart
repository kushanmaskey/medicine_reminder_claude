import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../services/storage_service.dart';
import '../screens/add_activity_screen.dart';
import '../screens/activity_detail_screen.dart';

const _typeConfig = {
  'Walk':       (icon: Icons.directions_walk,  color: Color(0xFF22C55E), bg: Color(0xFFF0FDF4)),
  'Run':        (icon: Icons.directions_run,   color: Color(0xFFF97316), bg: Color(0xFFFFF7ED)),
  'Exercise':   (icon: Icons.fitness_center,   color: Color(0xFF3B82F6), bg: Color(0xFFEFF6FF)),
  'Yoga':       (icon: Icons.self_improvement, color: Color(0xFF8B5CF6), bg: Color(0xFFF5F3FF)),
  'Meditation': (icon: Icons.spa,              color: Color(0xFF501513), bg: Color(0xFFECFDF5)),
};

class ActivitiesTab extends StatefulWidget {
  const ActivitiesTab({super.key});

  @override
  State<ActivitiesTab> createState() => ActivitiesTabState();
}

class ActivitiesTabState extends State<ActivitiesTab> {
  List<Activity> _activities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await StorageService.getActivities();
    final cutoff = DateTime.now().subtract(const Duration(days: 7));

    for (final a in list.where((a) => a.recordedAt.isBefore(cutoff))) {
      await StorageService.deleteActivity(a.id);
    }

    final recent = list
        .where((a) => !a.recordedAt.isBefore(cutoff))
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    if (mounted) setState(() { _activities = recent; _loading = false; });
  }

  void reload() => _load();

  List<_DayGroup> _groupByDay() {
    final dayMap = <String, List<Activity>>{};
    final dayDates = <String, DateTime>{};

    for (final a in _activities) {
      final dt = a.recordedAt.toLocal();
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      dayMap.putIfAbsent(key, () => []).add(a);
      dayDates.putIfAbsent(key, () => DateTime(dt.year, dt.month, dt.day));
    }

    final groups = <_DayGroup>[];
    for (final key in dayMap.keys) {
      final typeMap = <String, List<Activity>>{};
      for (final a in dayMap[key]!) {
        typeMap.putIfAbsent(a.type, () => []).add(a);
      }
      for (final entries in typeMap.values) {
        entries.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
      }
      final typeGroups = typeMap.entries
          .map((e) => _TypeGroup(type: e.key, entries: e.value))
          .toList()
        ..sort((a, b) => b.entries.last.recordedAt.compareTo(a.entries.last.recordedAt));
      groups.add(_DayGroup(date: dayDates[key]!, typeGroups: typeGroups));
    }

    return groups..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> _addForDay(DateTime date) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => AddActivityScreen(initialDate: date)),
    );
    if (result == true || result == 'deleted') _load();
  }

  Future<void> _openDetail(_TypeGroup tg, DateTime date) async {
    if (tg.entries.length == 1) {
      final result = await Navigator.push<dynamic>(
        context,
        MaterialPageRoute(builder: (_) => AddActivityScreen(existing: tg.entries.first)),
      );
      if (result == true || result == 'deleted') _load();
    } else {
      await Navigator.push<dynamic>(
        context,
        MaterialPageRoute(builder: (_) => ActivityDetailScreen(type: tg.type, date: date)),
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF22C55E)));
    }

    if (_activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_walk, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No Activities Logged Yet',
                style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Tap + to log your first activity',
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    }

    final groups = _groupByDay();

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF22C55E),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: groups.length,
        itemBuilder: (ctx, i) => _DayCard(
          group: groups[i],
          onAdd: () => _addForDay(groups[i].date),
          onOpenDetail: (tg) => _openDetail(tg, groups[i].date),
        ),
      ),
    );
  }
}

class _DayGroup {
  final DateTime date;
  final List<_TypeGroup> typeGroups;
  int get totalEntries => typeGroups.fold(0, (s, tg) => s + tg.entries.length);
  _DayGroup({required this.date, required this.typeGroups});
}

class _TypeGroup {
  final String type;
  final List<Activity> entries;
  _TypeGroup({required this.type, required this.entries});

  bool get isDistanceBased => type == 'Walk' || type == 'Run';

  String get displayValue {
    if (isDistanceBased) {
      final total = entries.fold<double>(0, (s, a) => s + (a.distance ?? 0));
      return total > 0 ? '${total.toStringAsFixed(1)} mi' : '—';
    }
    final total = entries.fold<double>(0, (s, a) => s + (a.duration ?? 0));
    return total > 0 ? '${total.toStringAsFixed(0)} min' : '—';
  }

  bool get hasNotes => entries.any((a) => a.notes.isNotEmpty);
}

class _DayCard extends StatelessWidget {
  final _DayGroup group;
  final VoidCallback onAdd;
  final void Function(_TypeGroup) onOpenDetail;

  const _DayCard({required this.group, required this.onAdd, required this.onOpenDetail});

  String _dayLabel(DateTime date) {
    final now = DateTime.now().toLocal();
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
      margin: const EdgeInsets.only(bottom: 14),
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
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
            child: Row(
              children: [
                Text(
                  _dayLabel(group.date),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${group.totalEntries} ${group.totalEntries == 1 ? 'entry' : 'entries'}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF22C55E),
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF22C55E),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
          ...group.typeGroups.asMap().entries.map((entry) {
            final isLast = entry.key == group.typeGroups.length - 1;
            return _TypeGroupRow(
              typeGroup: entry.value,
              isLast: isLast,
              onTap: () => onOpenDetail(entry.value),
            );
          }),
        ],
      ),
    );
  }
}

class _TypeGroupRow extends StatelessWidget {
  final _TypeGroup typeGroup;
  final bool isLast;
  final VoidCallback onTap;

  const _TypeGroupRow({required this.typeGroup, required this.isLast, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cfg = _typeConfig[typeGroup.type] ??
        (icon: Icons.directions_walk, color: const Color(0xFF22C55E), bg: const Color(0xFFF0FDF4));

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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: cfg.bg,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(cfg.icon, color: cfg.color, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          typeGroup.type,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF475569),
                          ),
                        ),
                        if (typeGroup.entries.length > 1) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: cfg.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${typeGroup.entries.length}×',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: cfg.color,
                              ),
                            ),
                          ),
                        ],
                        if (typeGroup.hasNotes) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.notes_outlined, size: 12, color: Colors.grey[400]),
                        ],
                      ],
                    ),
                  ),
                  if (typeGroup.displayValue != '—') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: cfg.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cfg.color.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        typeGroup.displayValue,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cfg.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
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
