import 'package:flutter/material.dart';
import '../models/vital.dart';
import '../services/storage_service.dart';
import '../screens/add_vital_screen.dart';

class VitalsTab extends StatefulWidget {
  const VitalsTab({super.key});

  @override
  State<VitalsTab> createState() => VitalsTabState();
}

class VitalsTabState extends State<VitalsTab> {
  List<Vital> _vitals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await StorageService.getVitals();
    final cutoff = DateTime.now().subtract(const Duration(days: 5));

    for (final v in list.where((v) => v.recordedAt.isBefore(cutoff))) {
      await StorageService.deleteVital(v.id);
    }

    final recent = list
        .where((v) => !v.recordedAt.isBefore(cutoff))
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    if (mounted) setState(() { _vitals = recent; _loading = false; });
  }

  void reload() => _load();

  Future<void> _open(Vital v) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => AddVitalScreen(existing: v)),
    );
    if (result == true || result == 'deleted') _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_vitals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.monitor_heart_outlined,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No Vitals Logged Yet',
                style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Tap + to log your first vitals reading',
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _vitals.length,
        itemBuilder: (ctx, i) => _VitalCard(
          vital: _vitals[i],
          onTap: () => _open(_vitals[i]),
        ),
      ),
    );
  }
}

class _VitalCard extends StatelessWidget {
  final Vital vital;
  final VoidCallback onTap;

  const _VitalCard({required this.vital, required this.onTap});

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
                // Header: date + risk badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.monitor_heart,
                          color: Color(0xFF0D9488), size: 17),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _formatDate(vital.recordedAt),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: _riskBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _riskColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 7, color: _riskColor),
                          const SizedBox(width: 4),
                          Text(
                            '${vital.riskLevel} Risk',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _riskColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // 4 vitals in a 2×2 grid, each icon+value on one line
                Row(
                  children: [
                    _MiniVital(
                      icon: Icons.favorite_outlined,
                      value: vital.bpDisplay,
                      color: const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 8),
                    _MiniVital(
                      icon: Icons.water_drop_outlined,
                      value: vital.sugarDisplay,
                      color: const Color(0xFFF97316),
                    ),
                    const SizedBox(width: 8),
                    _MiniVital(
                      icon: Icons.scale_outlined,
                      value: vital.weightDisplay,
                      color: const Color(0xFF3B82F6),
                    ),
                    const SizedBox(width: 8),
                    _MiniVital(
                      icon: Icons.biotech_outlined,
                      value: vital.cholesterolDisplay,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniVital extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _MiniVital({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
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
                  color: value == '—' ? Colors.grey[400] : color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
