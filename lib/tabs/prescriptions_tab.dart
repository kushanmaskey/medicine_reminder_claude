import 'package:flutter/material.dart';
import '../models/prescription.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../screens/add_prescription_screen.dart';

class PrescriptionsTab extends StatefulWidget {
  const PrescriptionsTab({super.key});

  @override
  State<PrescriptionsTab> createState() => PrescriptionsTabState();
}

class PrescriptionsTabState extends State<PrescriptionsTab> {
  List<Prescription> _prescriptions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await StorageService.getPrescriptions();
    if (mounted) setState(() { _prescriptions = list; _loading = false; });
  }

  void reload() => _load();

  Future<void> _delete(Prescription p) async {
    await StorageService.deletePrescription(p.id);
    await NotificationService.cancelNotification(
        NotificationService.idFromString(p.id));
    _load();
  }

  Future<void> _edit(Prescription p) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddPrescriptionScreen(existing: p),
      ),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_prescriptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No Prescriptions Yet',
                style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Tap + to add your first prescription',
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _prescriptions.length,
        itemBuilder: (ctx, i) {
          final p = _prescriptions[i];
          return _PrescriptionCard(
            prescription: p,
            onEdit: () => _edit(p),
            onDelete: () => _delete(p),
          );
        },
      ),
    );
  }
}

class _PrescriptionCard extends StatelessWidget {
  final Prescription prescription;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PrescriptionCard({
    required this.prescription,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final refill = prescription.refillDate;
    final daysLeft = refill?.difference(DateTime.now()).inDays;
    final isRefillUrgent = daysLeft != null && daysLeft <= 7;
    final isLowSupply = prescription.hasLowSupply;
    final isUrgent = isRefillUrgent || isLowSupply;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent ? Colors.orange.shade200 : Colors.grey.shade100,
        ),
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
          message: 'Tap to edit prescription',
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
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.description,
                          color: Color(0xFF3B82F6), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        prescription.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: Color(0xFF3B82F6), size: 20),
                      onPressed: onEdit,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Edit',
                    ),
                    const SizedBox(width: 8),
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
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.notes_outlined,
                  label: 'Instructions',
                  value: prescription.instructions,
                ),
                if (refill != null) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Refill Date',
                    value:
                        '${refill.day}/${refill.month}/${refill.year}  •  ${_daysLabel(daysLeft!)}',
                    valueColor: isRefillUrgent ? Colors.orange[700] : null,
                  ),
                ],
                if (prescription.totalPills != null &&
                    prescription.pillsPerDay != null) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.medication_outlined,
                    label: 'Pill Supply',
                    value:
                        '${prescription.totalPills} pills left  •  ${prescription.pillsPerDay}/day',
                    valueColor: isLowSupply ? Colors.orange[700] : null,
                  ),
                ],
                if (isLowSupply) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 14, color: Colors.orange[700]),
                        const SizedBox(width: 6),
                        Text(
                          'Low supply — consider refilling soon',
                          style: TextStyle(
                              fontSize: 12, color: Colors.orange[700]),
                        ),
                      ],
                    ),
                  ),
                ],
                if (prescription.notificationTime != null) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.notifications_active_outlined,
                    label: 'Reminder',
                    value: prescription.notificationTime!.format(context),
                    valueColor: const Color(0xFF3B82F6),
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

  String _daysLabel(int days) {
    if (days < 0) return 'Overdue';
    if (days == 0) return 'Today';
    if (days == 1) return '1 day left';
    return '$days days left';
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Prescription'),
        content: Text('Remove "${prescription.name}"?'),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.grey[400]),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13),
              children: [
                TextSpan(
                    text: '$label: ',
                    style: TextStyle(color: Colors.grey[500])),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: valueColor ?? const Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
