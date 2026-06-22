import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../services/storage_service.dart';
import 'add_activity_screen.dart';

const _typeConfig = {
  'Walk':       (icon: Icons.directions_walk,  color: Color(0xFF22C55E), bg: Color(0xFFF0FDF4)),
  'Run':        (icon: Icons.directions_run,   color: Color(0xFFF97316), bg: Color(0xFFFFF7ED)),
  'Exercise':   (icon: Icons.fitness_center,   color: Color(0xFF3B82F6), bg: Color(0xFFEFF6FF)),
  'Yoga':       (icon: Icons.self_improvement, color: Color(0xFF8B5CF6), bg: Color(0xFFF5F3FF)),
  'Meditation': (icon: Icons.spa,              color: Color(0xFF501513), bg: Color(0xFFECFDF5)),
};

class ActivityDetailScreen extends StatefulWidget {
  final String type;
  final DateTime date;

  const ActivityDetailScreen({super.key, required this.type, required this.date});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  List<Activity> _entries = [];
  bool _loading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final all = await StorageService.getActivities();
    final dayEnd = widget.date.add(const Duration(days: 1));
    final entries = all
        .where((a) =>
            a.type == widget.type &&
            !a.recordedAt.toLocal().isBefore(widget.date) &&
            a.recordedAt.toLocal().isBefore(dayEnd))
        .toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    if (mounted) setState(() { _entries = entries; _loading = false; });
  }

  Future<void> _edit(Activity a) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => AddActivityScreen(existing: a)),
    );
    if (result == true || result == 'deleted') {
      _changed = true;
      await _load();
      if (_entries.isEmpty && mounted) {
        Navigator.pop(context, 'deleted');
      }
    }
  }

  Future<void> _addEntry() async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => AddActivityScreen(
          initialDate: widget.date,
          initialType: widget.type,
        ),
      ),
    );
    if (result == true) {
      _changed = true;
      await _load();
    }
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour < 12 ? 'AM' : 'PM';
    return '${h.toString().padLeft(2, '0')}:$m $ampm';
  }

  String _dayLabel() {
    final now = DateTime.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (widget.date == today) return 'Today';
    if (widget.date == yesterday) return 'Yesterday';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[widget.date.month - 1]} ${widget.date.day}, ${widget.date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _typeConfig[widget.type] ??
        (icon: Icons.directions_walk, color: const Color(0xFF22C55E), bg: const Color(0xFFF0FDF4));

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
                widget.type,
                style: const TextStyle(
                  color: Color(0xFF484141),
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              Text(
                _dayLabel(),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: _addEntry,
              icon: Icon(Icons.add, color: cfg.color, size: 18),
              label: Text('Add', style: TextStyle(color: cfg.color, fontSize: 13)),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF22C55E)))
            : _entries.isEmpty
                ? Center(
                    child: Text(
                      'No entries',
                      style: TextStyle(color: Colors.grey[500], fontSize: 15),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
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
                            return _EntryRow(
                              activity: e.value,
                              time: _formatTime(e.value.recordedAt),
                              cfg: cfg,
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

class _EntryRow extends StatelessWidget {
  final Activity activity;
  final String time;
  final ({IconData icon, Color color, Color bg}) cfg;
  final bool isLast;
  final VoidCallback onTap;

  const _EntryRow({
    required this.activity,
    required this.time,
    required this.cfg,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                    width: 70,
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
                    child: Row(
                      children: [
                        if (activity.type == 'Walk') ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: cfg.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              activity.walkType,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: cfg.color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (activity.notes.isNotEmpty)
                          Icon(Icons.notes_outlined, size: 12, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                  if (activity.displayValue != '—') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: cfg.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cfg.color.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        activity.displayValue,
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
