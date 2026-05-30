import 'package:flutter/material.dart';
import '../models/doctor.dart';
import '../services/storage_service.dart';
import '../screens/add_doctor_screen.dart';

const _accent = Color(0xFF0EA5E9);

class DoctorsTab extends StatefulWidget {
  const DoctorsTab({super.key});

  @override
  State<DoctorsTab> createState() => DoctorsTabState();
}

class DoctorsTabState extends State<DoctorsTab> {
  List<Doctor> _doctors = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await StorageService.getDoctors();
      if (mounted) setState(() { _doctors = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void reload() => _load();

  Future<void> _open(Doctor d) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => AddDoctorScreen(existing: d)),
    );
    if (result == true || result == 'deleted') _load();
  }

  Future<void> openAdd() async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => const AddDoctorScreen()),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }

    if (_doctors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medical_services_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No Doctors Added Yet',
                style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Tap + to add your first doctor',
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: _accent,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _doctors.length,
        itemBuilder: (ctx, i) => _DoctorCard(
          doctor: _doctors[i],
          onTap: () => _open(_doctors[i]),
        ),
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback onTap;

  const _DoctorCard({required this.doctor, required this.onTap});

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
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.medical_services_outlined,
                      color: _accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctor.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF635A5A),
                        ),
                      ),
                      if (doctor.specialty.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          doctor.specialty,
                          style: const TextStyle(
                              fontSize: 12,
                              color: _accent,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                      const SizedBox(height: 3),
                      _buildSubtitle(doctor),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: Color(0xFFCBD5E1), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle(Doctor d) {
    final parts = <String>[];
    if (d.phone.isNotEmpty) parts.add(d.phone);
    final loc = [d.city, d.state].where((s) => s.isNotEmpty).join(', ');
    if (loc.isNotEmpty) parts.add(loc);

    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      parts.join(' · '),
      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
      overflow: TextOverflow.ellipsis,
    );
  }
}
