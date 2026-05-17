import 'package:flutter/material.dart';
import '../models/prescription.dart';
import '../models/appointment.dart';
import '../models/vital.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../screens/add_prescription_screen.dart';
import '../screens/add_appointment_screen.dart';
import '../screens/add_vital_screen.dart';

const _gradient = LinearGradient(
  colors: [Color(0xFF0D9488), Color(0xFF0891B2)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class SummaryTab extends StatefulWidget {
  final void Function(int) onTabChange;
  const SummaryTab({super.key, required this.onTabChange});

  @override
  State<SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<SummaryTab> {
  List<Prescription> _prescriptions = [];
  List<Appointment> _appointments = [];
  List<Vital> _vitals = [];
  String? _email;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      StorageService.getPrescriptions(),
      StorageService.getAppointments(),
      StorageService.getVitals(),
      AuthService.getEmail(),
    ]);
    if (!mounted) return;
    final appts = (results[1] as List<Appointment>)
      ..sort((a, b) => a.appointmentDateTime.compareTo(b.appointmentDateTime));
    final vitals = (results[2] as List<Vital>)
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    setState(() {
      _prescriptions = results[0] as List<Prescription>;
      _appointments = appts;
      _vitals = vitals;
      _email = results[3] as String?;
      _loading = false;
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  List<Appointment> get _upcomingAppointments => _appointments
      .where((a) => a.appointmentDateTime.isAfter(DateTime.now()))
      .toList();

  Vital? get _latestVital => _vitals.isEmpty ? null : _vitals.first;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF0D9488)));
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF0D9488),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _buildGreetingCard(),
          const SizedBox(height: 16),
          _buildStatsRow(),
          const SizedBox(height: 24),
          if (_latestVital != null) ...[
            _buildSectionHeader('Latest Vitals', Icons.monitor_heart_outlined,
                onViewAll: () => widget.onTabChange(3)),
            const SizedBox(height: 10),
            _buildLatestVitalsCard(_latestVital!),
            const SizedBox(height: 24),
          ],
          _buildSectionHeader('Upcoming Appointments',
              Icons.calendar_today_outlined,
              onViewAll: () => widget.onTabChange(2)),
          const SizedBox(height: 10),
          if (_upcomingAppointments.isEmpty)
            _buildEmptyState('No upcoming appointments',
                'Tap + on the Appointments tab to add one')
          else
            ..._upcomingAppointments.take(3).map((a) => _buildAppointmentRow(a)),
          const SizedBox(height: 24),
          _buildSectionHeader('Prescriptions', Icons.description_outlined,
              onViewAll: () => widget.onTabChange(1)),
          const SizedBox(height: 10),
          if (_prescriptions.isEmpty)
            _buildEmptyState('No prescriptions',
                'Tap + on the Prescriptions tab to add one')
          else
            ..._prescriptions.map((p) => _buildPrescriptionRow(p)),
        ],
      ),
    );
  }

  // ── Greeting card ──────────────────────────────────────────────────────────

  Widget _buildGreetingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.monitor_heart,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    )),
                if (_email != null) ...[
                  const SizedBox(height: 2),
                  Text(_email!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 4),
                Text(
                  'Here\'s your health overview',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Row(
      children: [
        _StatCard(
          label: 'Prescriptions',
          count: _prescriptions.length,
          icon: Icons.description_outlined,
          color: const Color(0xFF3B82F6),
          onTap: () => widget.onTabChange(1),
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Appointments',
          count: _upcomingAppointments.length,
          icon: Icons.calendar_today_outlined,
          color: const Color(0xFF8B5CF6),
          onTap: () => widget.onTabChange(2),
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Vitals Logged',
          count: _vitals.length,
          icon: Icons.monitor_heart_outlined,
          color: const Color(0xFF0D9488),
          onTap: () => widget.onTabChange(3),
        ),
      ],
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, IconData icon,
      {required VoidCallback onViewAll}) {
    return Row(
      children: [
        ShaderMask(
          shaderCallback: (b) =>
              _gradient.createShader(Rect.fromLTWH(0, 0, b.width, b.height)),
          blendMode: BlendMode.srcIn,
          child: Icon(icon, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 8),
        ShaderMask(
          shaderCallback: (b) =>
              _gradient.createShader(Rect.fromLTWH(0, 0, b.width, b.height)),
          blendMode: BlendMode.srcIn,
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onViewAll,
          child: ShaderMask(
            shaderCallback: (b) => _gradient
                .createShader(Rect.fromLTWH(0, 0, b.width, b.height)),
            blendMode: BlendMode.srcIn,
            child: const Text(
              'View All →',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Latest vitals card ─────────────────────────────────────────────────────

  Widget _buildLatestVitalsCard(Vital v) {
    final riskColor = v.riskLevel == 'High'
        ? const Color(0xFFEF4444)
        : v.riskLevel == 'Medium'
            ? const Color(0xFFF97316)
            : const Color(0xFF22C55E);

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => AddVitalScreen(existing: v)),
        );
        if (result == true) _load();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _fmtDateTime(v.recordedAt),
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: riskColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 7, color: riskColor),
                      const SizedBox(width: 4),
                      Text('${v.riskLevel} Risk',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: riskColor)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.edit_outlined,
                    size: 16, color: Color(0xFF0D9488)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _VitalChip(
                  icon: Icons.favorite_outlined,
                  label: 'Blood Pressure',
                  value: v.bpDisplay,
                  color: const Color(0xFFEF4444),
                ),
                const SizedBox(width: 10),
                _VitalChip(
                  icon: Icons.water_drop_outlined,
                  label: 'Sugar Level',
                  value: v.sugarDisplay,
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
                  value: v.weightDisplay,
                  color: const Color(0xFF3B82F6),
                ),
                const SizedBox(width: 10),
                const Expanded(child: SizedBox()),
              ],
            ),
            if (v.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.notes_outlined,
                      size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(v.notes,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Appointment row ────────────────────────────────────────────────────────

  Widget _buildAppointmentRow(Appointment a) {
    final dt = a.appointmentDateTime;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final apptDay = DateTime(dt.year, dt.month, dt.day);
    final diff = apptDay.difference(today).inDays;

    final color = diff == 0
        ? const Color(0xFFEF4444)
        : diff == 1
            ? const Color(0xFFF97316)
            : const Color(0xFF8B5CF6);

    final badge = diff == 0
        ? 'Today'
        : diff == 1
            ? 'Tomorrow'
            : 'In $diff days';

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
              builder: (_) => AddAppointmentScreen(existing: a)),
        );
        if (result == true) _load();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.calendar_month,
                  color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF1E293B))),
                  const SizedBox(height: 3),
                  Text(
                    '${a.doctorName}${a.location.isNotEmpty ? '  •  ${a.location}' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(_fmtDateTime(dt),
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[400])),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(badge,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ),
                const SizedBox(height: 4),
                Icon(Icons.edit_outlined,
                    size: 14, color: Colors.grey[400]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Prescription row ───────────────────────────────────────────────────────

  Widget _buildPrescriptionRow(Prescription p) {
    final daysLeft =
        p.refillDate.difference(DateTime.now()).inDays;
    final isUrgent = daysLeft <= 7;
    final color = isUrgent
        ? (daysLeft <= 0 ? const Color(0xFFEF4444) : const Color(0xFFF97316))
        : const Color(0xFF3B82F6);
    final badge = daysLeft < 0
        ? 'Overdue'
        : daysLeft == 0
            ? 'Today'
            : '$daysLeft days left';

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
              builder: (_) => AddPrescriptionScreen(existing: p)),
        );
        if (result == true) _load();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUrgent
                ? color.withValues(alpha: 0.3)
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
                  Text(p.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF1E293B))),
                  const SizedBox(height: 3),
                  Text(p.instructions,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[500]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (p.notificationTime != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.notifications_active_outlined,
                            size: 11, color: Colors.grey[400]),
                        const SizedBox(width: 3),
                        Text(
                          'Reminder: ${p.notificationTime!.format(context)}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(badge,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ),
                const SizedBox(height: 4),
                Icon(Icons.edit_outlined,
                    size: 14, color: Colors.grey[400]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Text(title,
              style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmtDateTime(DateTime dt) {
    final months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final h = dt.hour == 0 ? 12 : dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final p = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  •  $h:$m $p';
  }
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 8),
              Text('$count',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color)),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: color.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500)),
                  Text(value,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color:
                              value == '—' ? Colors.grey[400] : color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
