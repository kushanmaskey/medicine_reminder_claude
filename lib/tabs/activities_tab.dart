import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../services/storage_service.dart';
import '../screens/add_activity_screen.dart';

const _typeConfig = {
  'Walk':      (icon: Icons.directions_walk,  color: Color(0xFF22C55E), bg: Color(0xFFF0FDF4)),
  'Run':       (icon: Icons.directions_run,   color: Color(0xFFF97316), bg: Color(0xFFFFF7ED)),
  'Exercise':  (icon: Icons.fitness_center,   color: Color(0xFF3B82F6), bg: Color(0xFFEFF6FF)),
  'Yoga':      (icon: Icons.self_improvement, color: Color(0xFF8B5CF6), bg: Color(0xFFF5F3FF)),
  'Meditation':(icon: Icons.spa,              color: Color(0xFF0D9488), bg: Color(0xFFECFDF5)),
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

    final recent = (list
        .where((a) => !a.recordedAt.isBefore(cutoff))
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt)))
        .take(10)
        .toList();
    if (mounted) setState(() { _activities = recent; _loading = false; });
  }

  void reload() => _load();

  Future<void> _open(Activity a) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => AddActivityScreen(existing: a)),
    );
    if (result == true || result == 'deleted') _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF22C55E)));
    }

    if (_activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_walk, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No Activities Logged Yet',
                style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Tap + to log your first activity',
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF22C55E),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _activities.length,
        itemBuilder: (ctx, i) => _ActivityCard(
          activity: _activities[i],
          onTap: () => _open(_activities[i]),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final Activity activity;
  final VoidCallback onTap;

  const _ActivityCard({required this.activity, required this.onTap});

  String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _typeConfig[activity.type] ??
        (icon: Icons.directions_walk, color: const Color(0xFF22C55E), bg: const Color(0xFFF0FDF4));

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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cfg.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(cfg.icon, color: cfg.color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            activity.type,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          if (activity.type == 'Walk') ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: cfg.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                activity.walkType,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: cfg.color),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatDate(activity.recordedAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                _ValueBadge(value: activity.displayValue, color: cfg.color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ValueBadge extends StatelessWidget {
  final String value;
  final Color color;
  const _ValueBadge({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    if (value == '—') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        value,
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
