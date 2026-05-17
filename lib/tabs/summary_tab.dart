import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/prescription.dart';
import '../models/appointment.dart';
import '../models/vital.dart';
import '../models/activity.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../screens/add_prescription_screen.dart';
import '../screens/add_appointment_screen.dart';
import '../screens/add_vital_screen.dart';
import '../screens/add_activity_screen.dart';

const _defaultAvatarBgs = [
  Color(0xFF0D9488), Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFFEF4444),
  Color(0xFFEC4899), Color(0xFFF59E0B), Color(0xFF22C55E), Color(0xFF14B8A6),
  Color(0xFFF97316), Color(0xFF6366F1), Color(0xFF84CC16), Color(0xFF0EA5E9),
];

const _defaultAvatarIcons = [
  Icons.person, Icons.face, Icons.sentiment_satisfied, Icons.local_hospital,
  Icons.favorite, Icons.star, Icons.self_improvement, Icons.emoji_nature,
  Icons.sports_soccer, Icons.music_note, Icons.pets, Icons.flight,
];

const _tealGradient = LinearGradient(
  colors: [Color(0xFF0D9488), Color(0xFF0891B2)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const _pinkGradient = LinearGradient(
  colors: [Color(0xFFEC4899), Color(0xFF9333EA)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class SummaryTab extends StatefulWidget {
  final void Function(int) onTabChange;
  const SummaryTab({super.key, required this.onTabChange});

  @override
  State<SummaryTab> createState() => SummaryTabState();
}

class SummaryTabState extends State<SummaryTab> {
  List<Prescription> _prescriptions = [];
  List<Appointment> _appointments = [];
  List<Vital> _vitals = [];
  List<Activity> _activities = [];
  String? _email;
  String? _name;
  String? _sex;
  String? _avatarType;
  int? _avatarIndex;
  Uint8List? _avatarImageBytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void reload() => _load();

  Future<void> _load() async {
    final results = await Future.wait([
      StorageService.getPrescriptions(),
      StorageService.getAppointments(),
      StorageService.getVitals(),
      AuthService.getEmail(),
      StorageService.getActivities(),
      AuthService.getName(),
      AuthService.getSex(),
      AuthService.getAvatarData(),
    ]);
    if (!mounted) return;
    final appts = (results[1] as List<Appointment>)
      ..sort((a, b) => a.appointmentDateTime.compareTo(b.appointmentDateTime));
    final vitals = (results[2] as List<Vital>)
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final activities = (results[4] as List<Activity>)
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final avatarData = results[7] as Map<String, dynamic>;
    Uint8List? imageBytes;
    if (avatarData['type'] == 'custom' && avatarData['image'] != null) {
      imageBytes = base64Decode(avatarData['image'] as String);
    }
    setState(() {
      _prescriptions = results[0] as List<Prescription>;
      _appointments = appts;
      _vitals = vitals;
      _email = results[3] as String?;
      _activities = activities;
      _name = results[5] as String?;
      _sex = results[6] as String?;
      _avatarType = avatarData['type'] as String?;
      _avatarIndex = avatarData['index'] as int?;
      _avatarImageBytes = imageBytes;
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
          const SizedBox(height: 24),
          _buildSectionHeader('Recent Activities', Icons.directions_walk_outlined,
              onViewAll: () => widget.onTabChange(4)),
          const SizedBox(height: 10),
          if (_activities.isEmpty)
            _buildEmptyState('No activities logged',
                'Tap + on the Activities tab to log one')
          else
            ..._activities.take(3).map((a) => _buildActivityRow(a)),
        ],
      ),
    );
  }

  // ── Avatar helpers ─────────────────────────────────────────────────────────

  Widget _buildGreetingAvatar() {
    if (_avatarType == 'custom' && _avatarImageBytes != null) {
      return CircleAvatar(
        radius: 26,
        backgroundImage: MemoryImage(_avatarImageBytes!),
      );
    }
    if (_avatarType == 'default' &&
        _avatarIndex != null &&
        _avatarIndex! < _defaultAvatarBgs.length) {
      return CircleAvatar(
        radius: 26,
        backgroundColor: Colors.white.withValues(alpha: 0.25),
        child: Icon(_defaultAvatarIcons[_avatarIndex!],
            color: Colors.white, size: 28),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.monitor_heart, color: Colors.white, size: 28),
    );
  }

  // ── Greeting card ──────────────────────────────────────────────────────────

  LinearGradient get _greetingGradient =>
      _sex == 'Female' ? _pinkGradient : _tealGradient;

  Color get _greetingShadowColor =>
      _sex == 'Female' ? const Color(0xFFEC4899) : const Color(0xFF0D9488);

  Widget _buildGreetingCard() {
    final displayName = (_name != null && _name!.isNotEmpty) ? _name! : _email;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _greetingGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _greetingShadowColor.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildGreetingAvatar(),
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
                if (displayName != null) ...[
                  const SizedBox(height: 2),
                  Text(displayName,
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
    return Column(
      children: [
        Row(
          children: [
            _StatCard(
              label: 'Prescriptions',
              count: _prescriptions.length,
              icon: Icons.description_outlined,
              color: const Color(0xFF3B82F6),
              tooltip: 'View all prescriptions',
              onTap: () => widget.onTabChange(1),
            ),
            const SizedBox(width: 10),
            _StatCard(
              label: 'Appointments',
              count: _upcomingAppointments.length,
              icon: Icons.calendar_today_outlined,
              color: const Color(0xFF8B5CF6),
              tooltip: 'View upcoming appointments',
              onTap: () => widget.onTabChange(2),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _StatCard(
              label: 'Vitals Logged',
              count: _vitals.length,
              icon: Icons.monitor_heart_outlined,
              color: const Color(0xFF0D9488),
              tooltip: 'View vitals history',
              onTap: () => widget.onTabChange(3),
            ),
            const SizedBox(width: 10),
            _StatCard(
              label: 'Activities',
              count: _activities.length,
              icon: Icons.directions_walk_outlined,
              color: const Color(0xFF22C55E),
              tooltip: 'View all activities',
              onTap: () => widget.onTabChange(4),
            ),
          ],
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
              _tealGradient.createShader(Rect.fromLTWH(0, 0, b.width, b.height)),
          blendMode: BlendMode.srcIn,
          child: Icon(icon, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 8),
        ShaderMask(
          shaderCallback: (b) =>
              _tealGradient.createShader(Rect.fromLTWH(0, 0, b.width, b.height)),
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
        Tooltip(
          message: 'View all $title',
          child: GestureDetector(
          onTap: onViewAll,
          child: ShaderMask(
            shaderCallback: (b) => _tealGradient
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

    return Tooltip(
      message: 'Tap to edit latest vitals',
      child: GestureDetector(
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

    return Tooltip(
      message: 'Tap to edit appointment',
      child: GestureDetector(
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

    return Tooltip(
      message: 'Tap to edit prescription',
      child: GestureDetector(
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
      ),
    );
  }

  // ── Activity row ───────────────────────────────────────────────────────────

  static const _activityColors = {
    'Walk':       Color(0xFF22C55E),
    'Run':        Color(0xFFF97316),
    'Exercise':   Color(0xFF3B82F6),
    'Yoga':       Color(0xFF8B5CF6),
    'Meditation': Color(0xFF0D9488),
  };

  static const _activityIcons = {
    'Walk':       Icons.directions_walk,
    'Run':        Icons.directions_run,
    'Exercise':   Icons.fitness_center,
    'Yoga':       Icons.self_improvement,
    'Meditation': Icons.spa,
  };

  Widget _buildActivityRow(Activity a) {
    final color = _activityColors[a.type] ?? const Color(0xFF22C55E);
    final icon  = _activityIcons[a.type]  ?? Icons.directions_walk;

    return Tooltip(
      message: 'Tap to edit activity',
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => AddActivityScreen(existing: a)),
          );
          if (result == true) _load();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
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
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(a.type,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF1E293B))),
                        if (a.type == 'Walk') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(a.walkType,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: color)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(_fmtDateTime(a.recordedAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(a.displayValue,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ),
                  const SizedBox(height: 4),
                  Icon(Icons.edit_outlined, size: 14, color: Colors.grey[400]),
                ],
              ),
            ],
          ),
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
  final String? tooltip;

  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: tooltip ?? 'View $label',
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
