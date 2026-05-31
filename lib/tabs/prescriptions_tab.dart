import 'package:flutter/material.dart';
import '../models/prescription.dart';
import '../models/doctor.dart';
import '../services/storage_service.dart';
import '../screens/add_prescription_screen.dart';

class PrescriptionsTab extends StatefulWidget {
  const PrescriptionsTab({super.key});

  @override
  State<PrescriptionsTab> createState() => PrescriptionsTabState();
}

class PrescriptionsTabState extends State<PrescriptionsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Prescription> _prescriptions = [];
  Map<String, Doctor> _doctorMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      StorageService.getPrescriptions(),
      StorageService.getDoctors(),
    ]);
    final prescriptions = results[0] as List<Prescription>;
    final doctors = results[1] as List<Doctor>;
    if (mounted) {
      setState(() {
        _prescriptions = prescriptions;
        _doctorMap = {for (final d in doctors) d.id: d};
        _loading = false;
      });
    }
  }

  void reload() => _load();

  Future<void> openAdd() async {
    final type = _tabController.index == 0 ? 'prescribed' : 'otc';
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => AddPrescriptionScreen(type: type),
      ),
    );
    if (result == true || result == 'deleted') _load();
  }

  Future<void> _open(Prescription p) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => AddPrescriptionScreen(existing: p)),
    );
    if (result == true || result == 'deleted') _load();
  }

  List<Prescription> get _prescribed =>
      _prescriptions.where((p) => p.type == 'prescribed').toList();

  List<Prescription> get _otc =>
      _prescriptions.where((p) => p.type == 'otc').toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF3B82F6),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF3B82F6),
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Prescribed'),
              Tab(text: 'Over the Counter'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _PrescriptionList(
                      items: _prescribed,
                      doctorMap: _doctorMap,
                      emptyMessage: 'No prescribed medications yet',
                      emptyHint: 'Tap + to add a prescription',
                      onTap: _open,
                      onRefresh: _load,
                    ),
                    _PrescriptionList(
                      items: _otc,
                      doctorMap: _doctorMap,
                      emptyMessage: 'No OTC medications yet',
                      emptyHint: 'Tap + to add an over-the-counter medication',
                      onTap: _open,
                      onRefresh: _load,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _PrescriptionList extends StatelessWidget {
  final List<Prescription> items;
  final Map<String, Doctor> doctorMap;
  final String emptyMessage;
  final String emptyHint;
  final void Function(Prescription) onTap;
  final Future<void> Function() onRefresh;

  const _PrescriptionList({
    required this.items,
    required this.doctorMap,
    required this.emptyMessage,
    required this.emptyHint,
    required this.onTap,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(emptyMessage,
                style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(emptyHint,
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (ctx, i) => _PrescriptionCard(
          prescription: items[i],
          doctor: items[i].doctorId != null ? doctorMap[items[i].doctorId] : null,
          onTap: () => onTap(items[i]),
        ),
      ),
    );
  }
}

class _PrescriptionCard extends StatelessWidget {
  final Prescription prescription;
  final Doctor? doctor;
  final VoidCallback onTap;

  const _PrescriptionCard({required this.prescription, this.doctor, required this.onTap});

  String _refillLabel(DateTime? refill) {
    if (refill == null) return 'No refill date set';
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final days = refill.difference(DateTime.now()).inDays;
    final suffix = days < 0 ? 'Overdue' : days == 0 ? 'Today' : 'In $days days';
    return '${months[refill.month - 1]} ${refill.day}, ${refill.year}  •  $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final refill = prescription.refillDate;
    final daysLeft = refill?.difference(DateTime.now()).inDays;
    final isRefillUrgent = daysLeft != null && daysLeft <= 7;
    final isLowSupply = prescription.hasLowSupply;
    final isUrgent = isRefillUrgent || isLowSupply;
    final badgeColor = isUrgent
        ? (daysLeft != null && daysLeft <= 0
            ? const Color(0xFFEF4444)
            : const Color(0xFFF97316))
        : const Color(0xFF3B82F6);
    final badge = isLowSupply && (daysLeft == null || daysLeft > 7)
        ? 'Low supply'
        : daysLeft == null
            ? null
            : daysLeft < 0
                ? 'Overdue'
                : daysLeft == 0
                    ? 'Today'
                    : '$daysLeft days left';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUrgent
              ? badgeColor.withValues(alpha: 0.25)
              : Colors.grey.shade100,
          width: isUrgent ? 1.5 : 1,
        ),
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
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.description,
                      color: Color(0xFF3B82F6), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prescription.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF635A5A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (prescription.isOtc)
                        Text(
                          prescription.instructions.isNotEmpty
                              ? prescription.instructions
                              : 'Over the counter',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        )
                      else ...[
                        Text(
                          _refillLabel(refill),
                          style: TextStyle(
                            fontSize: 11,
                            color: isRefillUrgent
                                ? const Color(0xFFF97316)
                                : Colors.grey[500],
                          ),
                        ),
                        if (doctor != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.person_outline,
                                  size: 11, color: Colors.grey[400]),
                              const SizedBox(width: 3),
                              Text(
                                doctor!.fullName,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[400]),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                if (badge != null && !prescription.isOtc) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: badgeColor),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
