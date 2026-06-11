import 'package:flutter/material.dart';
import '../models/insurance.dart';
import '../services/storage_service.dart';
import '../screens/add_insurance_screen.dart';

const _accent = Color(0xFF059669);
const _primary = Color(0xFF501513);

class InsuranceTab extends StatefulWidget {
  const InsuranceTab({super.key});

  @override
  State<InsuranceTab> createState() => InsuranceTabState();
}

class InsuranceTabState extends State<InsuranceTab> {
  List<Insurance> _insurances = [];
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final list = await StorageService.getInsurances();
      if (mounted) {
        setState(() {
          _insurances = list;
          _loading = false;
          _loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _loadFailed = true; });
    }
  }

  void reload() => _load();

  Future<void> openAdd() async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => const AddInsuranceScreen()),
    );
    if (result == true || result == 'deleted') _load();
  }

  Future<void> _openEdit(Insurance ins) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => AddInsuranceScreen(existing: ins)),
    );
    if (result == true || result == 'deleted') _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: Colors.white,
        child: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    if (_loadFailed) {
      return ColoredBox(
        color: Colors.white,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('Could not load insurance',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 6),
                const Text('Check your internet connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    if (_insurances.isEmpty) {
      return const ColoredBox(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.health_and_safety_outlined, size: 64, color: Color(0xFFE2E8F0)),
              SizedBox(height: 16),
              Text(
                'No Insurance Added',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Tap + to add your insurance info',
                style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: _primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _insurances.length,
        itemBuilder: (_, i) => _InsuranceCard(
          insurance: _insurances[i],
          onTap: () => _openEdit(_insurances[i]),
        ),
      ),
    );
  }
}

class _InsuranceCard extends StatelessWidget {
  final Insurance insurance;
  final VoidCallback onTap;

  const _InsuranceCard({required this.insurance, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ins = insurance;
    final Color statusColor;
    final String? statusBadge;

    if (ins.isExpired) {
      statusColor = const Color(0xFFEF4444);
      statusBadge = 'Expired';
    } else if (ins.isExpiringSoon) {
      statusColor = const Color(0xFFF97316);
      statusBadge = 'Expiring Soon';
    } else {
      statusColor = _accent;
      statusBadge = ins.expirationDate != null ? 'Active' : null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ins.isExpired || ins.isExpiringSoon
              ? statusColor.withValues(alpha: 0.3)
              : Colors.grey.shade100,
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
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.health_and_safety_outlined,
                      color: _accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ins.providerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF635A5A),
                        ),
                      ),
                      if (ins.planName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          ins.planName,
                          style: const TextStyle(
                              fontSize: 12,
                              color: _accent,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                      if (ins.memberId.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Member ID: ${ins.memberId}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (statusBadge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusBadge,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusColor),
                        ),
                      ),
                    const SizedBox(height: 4),
                    const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1), size: 18),
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
