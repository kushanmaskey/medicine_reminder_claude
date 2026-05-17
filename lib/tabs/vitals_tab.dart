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
    list.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    if (mounted) setState(() { _vitals = list; _loading = false; });
  }

  void reload() => _load();

  Future<void> _delete(Vital v) async {
    await StorageService.deleteVital(v.id);
    _load();
  }

  Future<void> _edit(Vital v) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddVitalScreen(existing: v),
      ),
    );
    if (result == true) _load();
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
          onEdit: () => _edit(_vitals[i]),
          onDelete: () => _delete(_vitals[i]),
        ),
      ),
    );
  }
}

class _VitalCard extends StatelessWidget {
  final Vital vital;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VitalCard({
    required this.vital,
    required this.onEdit,
    required this.onDelete,
  });

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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: Tooltip(
          message: 'Tap to edit vitals',
          child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.monitor_heart,
                          color: Color(0xFF0D9488), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _formatDateTime(vital.recordedAt),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _riskBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _riskColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 8, color: _riskColor),
                          const SizedBox(width: 5),
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
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: Color(0xFF0D9488), size: 20),
                      onPressed: onEdit,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Edit',
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 20),
                      onPressed: () => _confirmDelete(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _VitalChip(
                      icon: Icons.favorite_outlined,
                      label: 'Blood Pressure',
                      value: vital.bpDisplay,
                      color: const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 10),
                    _VitalChip(
                      icon: Icons.water_drop_outlined,
                      label: 'Sugar Level',
                      value: vital.sugarDisplay,
                      color: const Color(0xFFF97316),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _VitalChip(
                      icon: Icons.scale_outlined,
                      label: 'Weight',
                      value: vital.weightDisplay,
                      color: const Color(0xFF3B82F6),
                    ),
                    const SizedBox(width: 10),
                    _VitalChip(
                      icon: Icons.biotech_outlined,
                      label: 'Cholesterol',
                      value: vital.cholesterolDisplay,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ],
                ),
                if (vital.colonoscopyDate != null ||
                    vital.periodDate != null ||
                    vital.mammogramDate != null) ...[
                  const SizedBox(height: 10),
                  if (vital.colonoscopyDate != null)
                    _DateRow(
                      icon: Icons.medical_services_outlined,
                      label: 'Last Colonoscopy',
                      value: vital.colonoscopyDisplay,
                      color: const Color(0xFF14B8A6),
                    ),
                  if (vital.periodDate != null)
                    _DateRow(
                      icon: Icons.calendar_month_outlined,
                      label: 'Last Period',
                      value: vital.periodDisplay,
                      color: const Color(0xFFEC4899),
                    ),
                  if (vital.mammogramDate != null)
                    _DateRow(
                      icon: Icons.medical_information_outlined,
                      label: 'Last Mammogram',
                      value: vital.mammogramDisplay,
                      color: const Color(0xFFEC4899),
                    ),
                ],
                if (vital.notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notes_outlined,
                          size: 15, color: Colors.grey[400]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          vital.notes,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour =
        dt.hour == 0 ? 12 : dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  •  $hour:$minute $period';
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reading'),
        content:
            Text('Remove vitals recorded on ${_formatDateTime(vital.recordedAt)}?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); onDelete(); },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DateRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _VitalChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _VitalChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500)),
                  Text(value,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: value == '—' ? Colors.grey[400] : color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
