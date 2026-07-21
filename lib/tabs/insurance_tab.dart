import 'package:flutter/material.dart';
import '../models/insurance.dart';
import '../services/storage_service.dart';
import '../screens/add_insurance_screen.dart';

const _primary = Color(0xFFFF6B6B);
const _accent = Color(0xFF059669);

const _types = ['Health', 'Dental', 'Vision'];

const _typeIcons = {
  'Health': Icons.health_and_safety_outlined,
  'Dental': Icons.sentiment_satisfied_outlined,
  'Vision': Icons.visibility_outlined,
};

const _typeColors = {
  'Health': Color(0xFF059669),
  'Dental': Color(0xFF3B82F6),
  'Vision': Color(0xFF8B5CF6),
};

class InsuranceTab extends StatefulWidget {
  final VoidCallback? onChanged;
  const InsuranceTab({super.key, this.onChanged});

  @override
  State<InsuranceTab> createState() => InsuranceTabState();
}

class InsuranceTabState extends State<InsuranceTab>
    with SingleTickerProviderStateMixin {
  List<Insurance> _insurances = [];
  bool _loading = true;
  bool _loadFailed = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    final type = _types[_tabController.index];
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => AddInsuranceScreen(insuranceType: type),
      ),
    );
    if (result == true || result == 'deleted') _load();
  }

  Future<void> _openEdit(Insurance ins) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => AddInsuranceScreen(existing: ins)),
    );
    if (result == true || result == 'deleted') {
      _load();
      widget.onChanged?.call();
    }
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

    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: _primary,
              unselectedLabelColor: const Color(0xFF94A3B8),
              indicatorColor: _primary,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: _types.map((t) => Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_typeIcons[t], size: 16,
                        color: _tabController.index == _types.indexOf(t)
                            ? _typeColors[t]
                            : const Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Text(t),
                  ],
                ),
              )).toList(),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _types.map((t) => _buildTypeList(t)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeList(String type) {
    final list = _insurances.where((ins) => ins.type == type).toList();
    final color = _typeColors[type] ?? _accent;
    final icon = _typeIcons[type] ?? Icons.health_and_safety_outlined;

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: const Color(0xFFE2E8F0)),
            const SizedBox(height: 16),
            Text(
              'No $type Insurance Added',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add your $type insurance',
              style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: _primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (_, i) => _InsuranceCard(
          insurance: list[i],
          color: color,
          icon: icon,
          onTap: () => _openEdit(list[i]),
        ),
      ),
    );
  }
}

class _InsuranceCard extends StatelessWidget {
  final Insurance insurance;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _InsuranceCard({
    required this.insurance,
    required this.color,
    required this.icon,
    required this.onTap,
  });

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
    } else if (ins.expirationDate != null) {
      statusColor = color;
      statusBadge = 'Active';
    } else {
      statusColor = color;
      statusBadge = null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (ins.isExpired || ins.isExpiringSoon)
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
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
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
                        Text(ins.planName,
                            style: TextStyle(
                                fontSize: 12,
                                color: color,
                                fontWeight: FontWeight.w500)),
                      ],
                      if (ins.memberId.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Member ID: ${ins.memberId}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                            overflow: TextOverflow.ellipsis),
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
                        child: Text(statusBadge,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: statusColor)),
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
