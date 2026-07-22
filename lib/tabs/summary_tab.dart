import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/prescription.dart';
import '../models/appointment.dart';
import '../models/vital.dart';
import '../models/activity.dart';
import '../models/allergy.dart';
import '../models/doctor.dart';
import '../models/insurance.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../screens/add_prescription_screen.dart';
import '../screens/add_appointment_screen.dart';
import '../screens/add_vital_screen.dart';
import '../screens/add_activity_screen.dart';
import '../screens/add_doctor_screen.dart';
import '../screens/add_allergy_screen.dart';
import '../screens/add_insurance_screen.dart';

const _defaultAvatarBgs = [
  Color(0xFFFF6B6B), Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFFEF4444),
  Color(0xFFFF8C42), Color(0xFFF59E0B), Color(0xFF22C55E), Color(0xFF14B8A6),
  Color(0xFFF97316), Color(0xFF6366F1), Color(0xFF84CC16), Color(0xFF0EA5E9),
];

const _defaultAvatarIcons = [
  Icons.person, Icons.face, Icons.sentiment_satisfied, Icons.local_hospital,
  Icons.favorite, Icons.star, Icons.self_improvement, Icons.emoji_nature,
  Icons.sports_soccer, Icons.music_note, Icons.pets, Icons.flight,
];

const _tealGradient = LinearGradient(
  colors: [Color(0xFFFF6B6B), Color(0xFFFF8C42)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const _pinkGradient = LinearGradient(
  colors: [Color(0xFFFF8C42), Color(0xFF9333EA)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class SummaryTab extends StatefulWidget {
  final void Function(int) onTabChange;
  final VoidCallback? onVitalChanged;
  final VoidCallback? onAllergyChanged;
  final VoidCallback? onPrescriptionChanged;
  final VoidCallback? onAppointmentChanged;
  final VoidCallback? onActivityChanged;
  final VoidCallback? onDoctorChanged;
  final VoidCallback? onInsuranceChanged;
  const SummaryTab({
    super.key,
    required this.onTabChange,
    this.onVitalChanged,
    this.onAllergyChanged,
    this.onPrescriptionChanged,
    this.onAppointmentChanged,
    this.onActivityChanged,
    this.onDoctorChanged,
    this.onInsuranceChanged,
  });

  @override
  State<SummaryTab> createState() => SummaryTabState();
}

class SummaryTabState extends State<SummaryTab> {
  List<Prescription> _prescriptions = [];
  List<Appointment> _appointments = [];
  List<Vital> _vitals = [];
  List<Activity> _activities = [];
  List<Allergy> _allergies = [];
  List<Doctor> _doctors = [];
  List<Insurance> _insurances = [];
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
    // Load each section independently so a failure in one doesn't blank the others.
    List<Prescription> prescriptions = [];
    List<Appointment> appointments = [];
    List<Vital> vitals = [];
    List<Activity> activities = [];
    List<Allergy> allergies = [];
    List<Doctor> doctors = [];
    List<Insurance> insurances = [];
    String? name;
    String? sex;
    Map<String, dynamic> avatarData = {};

    await Future.wait([
      StorageService.getPrescriptions().then((v) { prescriptions = v; }).catchError((_) {}),
      StorageService.getAppointments().then((v) { appointments = v; }).catchError((_) {}),
      StorageService.getVitals().then((v) { vitals = v; }).catchError((_) {}),
      StorageService.getActivities().then((v) { activities = v; }).catchError((_) {}),
      StorageService.getAllergies().then((v) { allergies = v; }).catchError((_) {}),
      StorageService.getDoctors().then((v) { doctors = v; }).catchError((_) {}),
      StorageService.getInsurances().then((v) { insurances = v; }).catchError((_) {}),
      AuthService.getName().then((v) { name = v; }).catchError((_) {}),
      AuthService.getSex().then((v) { sex = v; }).catchError((_) {}),
      AuthService.getAvatarData().then((v) { avatarData = v; }).catchError((_) {}),
    ]);

    if (!mounted) return;

    appointments.sort((a, b) => a.appointmentDateTime.compareTo(b.appointmentDateTime));
    vitals.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    activities.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    Uint8List? imageBytes;
    if (avatarData['type'] == 'custom' && avatarData['image'] != null) {
      try { imageBytes = base64Decode(avatarData['image'] as String); } catch (_) {}
    }

    setState(() {
      _prescriptions = prescriptions;
      _appointments = appointments;
      _vitals = vitals;
      _activities = activities;
      _allergies = allergies;
      _doctors = doctors;
      _insurances = insurances;
      _name = name;
      _sex = sex;
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

  List<Appointment> get _upcomingAppointments {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _appointments.where((a) {
      final apptDay = DateTime(a.appointmentDateTime.year,
          a.appointmentDateTime.month, a.appointmentDateTime.day);
      return !apptDay.isBefore(today);
    }).toList();
  }

  List<MapEntry<DateTime, List<Vital>>> get _vitalDayGroups {
    final groups = <DateTime, List<Vital>>{};
    for (final v in _vitals.where((v) => v.category == 'daily')) {
      final day = DateTime(v.recordedAt.year, v.recordedAt.month, v.recordedAt.day);
      groups.putIfAbsent(day, () => []).add(v);
    }
    final sorted = groups.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    return sorted.take(3).toList();
  }

  List<Prescription> get _rxPrescriptions =>
      _prescriptions.where((p) => !p.isOtc).toList();

  static const _dailyActivityTypes = {'Walk', 'Run', 'Exercise', 'Yoga', 'Meditation'};

  List<Activity> get _dailyActivities =>
      _activities.where((a) => _dailyActivityTypes.contains(a.type)).toList();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6B6B)));
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFFFF6B6B),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _buildGreetingCard(),
          const SizedBox(height: 16),
          _buildStatsRow(),
          const SizedBox(height: 24),
          if (_vitalDayGroups.isNotEmpty) ...[
            _buildSectionHeader('Latest Vitals', Icons.monitor_heart_outlined,
                onViewAll: () => widget.onTabChange(5)),
            const SizedBox(height: 10),
            ..._vitalDayGroups.map((e) => _buildVitalDayCard(e.key, e.value)),
            const SizedBox(height: 14),
          ],
          _buildSectionHeader('Upcoming Appointments',
              Icons.calendar_today_outlined,
              onViewAll: () => widget.onTabChange(4)),
          const SizedBox(height: 10),
          if (_upcomingAppointments.isEmpty)
            _buildEmptyState('No upcoming appointments',
                'Tap + on the Appointments tab to add one')
          else
            ..._upcomingAppointments.take(3).map((a) => _buildAppointmentRow(a)),
          const SizedBox(height: 24),
          _buildSectionHeader('Prescriptions', Icons.description_outlined,
              onViewAll: () => widget.onTabChange(3)),
          const SizedBox(height: 10),
          if (_rxPrescriptions.isEmpty)
            _buildEmptyState('No prescriptions',
                'Tap + on the Prescriptions tab to add one')
          else
            ..._rxPrescriptions.take(3).map((p) => _buildPrescriptionRow(p)),
          const SizedBox(height: 24),
          _buildSectionHeader('Recent Activities', Icons.directions_walk_outlined,
              onViewAll: () => widget.onTabChange(6)),
          const SizedBox(height: 10),
          if (_dailyActivities.isEmpty)
            _buildEmptyState('No activities logged',
                'Tap + on the Activities tab to log one')
          else
            ..._dailyActivities.take(3).map((a) => _buildActivityRow(a)),
          const SizedBox(height: 24),
          _buildSectionHeader('Allergies', Icons.coronavirus_outlined,
              onViewAll: () => widget.onTabChange(7)),
          const SizedBox(height: 10),
          if (_allergies.isEmpty)
            _buildEmptyState('No allergies recorded',
                'Tap + on the Allergies tab to add one')
          else
            ..._allergies.take(3).map((a) => _buildAllergyRow(a)),
          const SizedBox(height: 24),
          _buildSectionHeader('My Doctors', Icons.medical_services_outlined,
              onViewAll: () => widget.onTabChange(1)),
          const SizedBox(height: 10),
          if (_doctors.isEmpty)
            _buildEmptyState('No doctors added',
                'Tap + on the Doctors tab to add one')
          else
            ..._doctors.take(3).map((d) => _buildDoctorRow(d)),
          const SizedBox(height: 24),
          _buildSectionHeader('Insurance', Icons.health_and_safety_outlined,
              onViewAll: () => widget.onTabChange(2)),
          const SizedBox(height: 10),
          if (_insurances.isEmpty)
            _buildEmptyState('No insurance added',
                'Tap + on the Insurance tab to add one')
          else
            ...[
              _insurances.where((i) => i.type == 'Health').firstOrNull,
              _insurances.where((i) => i.type == 'Dental').firstOrNull,
              _insurances.where((i) => i.type == 'Vision').firstOrNull,
            ].whereType<Insurance>().map((ins) => _buildInsuranceRow(ins)),
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
      _sex == 'Female' ? const Color(0xFFFF8C42) : const Color(0xFFFF6B6B);

  Widget _buildGreetingCard() {
    final displayName = (_name != null && _name!.isNotEmpty) ? _name! : 'User';

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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StatCard(
            label: 'Doctors',
            count: _doctors.length,
            icon: Icons.medical_services_outlined,
            color: const Color(0xFF0EA5E9),
            onTap: () => widget.onTabChange(1),
          ),
          const SizedBox(width: 8),
          _StatCard(
            label: 'Insurance',
            count: _insurances.length,
            icon: Icons.health_and_safety_outlined,
            color: const Color(0xFF059669),
            onTap: () => widget.onTabChange(2),
          ),
          const SizedBox(width: 8),
          _StatCard(
            label: 'Rx',
            count: _rxPrescriptions.length,
            icon: Icons.description_outlined,
            color: const Color(0xFF3B82F6),
            onTap: () => widget.onTabChange(3),
          ),
          const SizedBox(width: 8),
          _StatCard(
            label: 'Appts',
            count: _upcomingAppointments.length,
            icon: Icons.calendar_today_outlined,
            color: const Color(0xFF8B5CF6),
            onTap: () => widget.onTabChange(4),
          ),
          const SizedBox(width: 8),
          _StatCard(
            label: 'Vitals',
            count: _vitals.where((v) => v.category == 'daily').length,
            icon: Icons.monitor_heart_outlined,
            color: const Color(0xFFFF6B6B),
            onTap: () => widget.onTabChange(5),
          ),
          const SizedBox(width: 8),
          _StatCard(
            label: 'Activity',
            count: _dailyActivities.length,
            icon: Icons.directions_walk_outlined,
            color: const Color(0xFF22C55E),
            onTap: () => widget.onTabChange(6),
          ),
          const SizedBox(width: 8),
          _StatCard(
            label: 'Allergies',
            count: _allergies.length,
            icon: Icons.coronavirus_outlined,
            color: const Color(0xFFF59E0B),
            onTap: () => widget.onTabChange(7),
          ),
        ],
      ),
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, IconData icon,
      {required VoidCallback onViewAll}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF484141)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF484141),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Tooltip(
          message: 'View all $title',
          child: GestureDetector(
            onTap: onViewAll,
            child: const Text(
              'View All →',
              style: TextStyle(
                color: Color(0xFF484141),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Vitals day card (grouped by date) ─────────────────────────────────────

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

Widget _buildVitalDayCard(DateTime date, List<Vital> vitals) {
    final bpRows    = <(DateTime, String)>[];
    final pulseRows = <(DateTime, String)>[];
    final sugarRows = <(DateTime, String)>[];
    final wtRows    = <(DateTime, String)>[];
    final cholRows  = <(DateTime, String)>[];

    for (final v in vitals) {
      for (final r in v.bpReadings) {
        bpRows.add((r.time, '${r.systolic}/${r.diastolic} mmHg'));
      }
      for (final r in v.pulseReadings) {
        pulseRows.add((r.time, '${r.value.toInt()} bpm'));
      }
      for (final r in v.sugarReadings) {
        sugarRows.add((r.time, '${r.value.toStringAsFixed(1)} ${v.sugarUnit}'));
      }
      for (final r in v.weightReadings) {
        wtRows.add((r.time, '${r.value.toStringAsFixed(1)} ${v.weightUnit}'));
      }
      for (final r in v.cholesterolReadings) {
        cholRows.add((r.time, '${r.value.toStringAsFixed(1)} ${v.cholesterolUnit}'));
      }
    }
    for (final list in [bpRows, pulseRows, sugarRows, wtRows, cholRows]) {
      list.sort((a, b) => a.$1.compareTo(b.$1));
    }

    final chips = <(String, IconData, Color)>[];
    if (bpRows.isNotEmpty)    chips.add((bpRows.last.$2,    Icons.favorite_outlined,      const Color(0xFFEF4444)));
    if (pulseRows.isNotEmpty) chips.add((pulseRows.last.$2, Icons.monitor_heart_outlined,  const Color(0xFFEC4899)));
    if (sugarRows.isNotEmpty) chips.add((sugarRows.last.$2, Icons.water_drop_outlined,     const Color(0xFFF97316)));
    if (wtRows.isNotEmpty)    chips.add((wtRows.last.$2,    Icons.scale_outlined,          const Color(0xFF3B82F6)));
    if (cholRows.isNotEmpty)  chips.add((cholRows.last.$2,  Icons.biotech_outlined,        const Color(0xFF8B5CF6)));

    return GestureDetector(
      onTap: () async {
        final vital = vitals.last;
        final result = await Navigator.push<dynamic>(
          context,
          MaterialPageRoute(
            builder: (_) => AddVitalScreen(
              existing: vital,
              category: 'daily',
              sameDayHistory: vitals.where((v) => v.id != vital.id).toList(),
            ),
          ),
        );
        if (result == true || result == 'deleted') {
          _load();
          widget.onVitalChanged?.call();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        child: Row(
          children: [
            Text(
              _dayLabel(date),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF484141),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 4,
                runSpacing: 3,
                children: chips.map((c) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.$3.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: c.$3.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(c.$2, size: 10, color: c.$3),
                      const SizedBox(width: 3),
                      Text(c.$1, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.$3)),
                    ],
                  ),
                )).toList(),
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
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
        final result = await Navigator.push<dynamic>(
          context,
          MaterialPageRoute(builder: (_) => AddAppointmentScreen(existing: a)),
        );
        if (result == true || result == 'deleted') {
          _load();
          widget.onAppointmentChanged?.call();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.calendar_month, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appt with ${a.doctorName}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF635A5A)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _fmtDateTime(dt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          ],
        ),
      ),
    );
  }

  // ── Prescription row ───────────────────────────────────────────────────────

  Widget _buildPrescriptionRow(Prescription p) {
    final refill = p.refillDate;
    final daysLeft = refill?.difference(DateTime.now()).inDays;
    final isRefillUrgent = daysLeft != null && daysLeft <= 7;
    final isLowSupply = p.hasLowSupply;
    final isUrgent = isRefillUrgent || isLowSupply;
    final color = isUrgent
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

    String refillLabel() {
      if (refill == null) return 'No refill date set';
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      final suffix = daysLeft! < 0 ? 'Overdue' : daysLeft == 0 ? 'Today' : 'In $daysLeft days';
      return '${months[refill.month - 1]} ${refill.day}, ${refill.year}  •  $suffix';
    }

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<dynamic>(
          context,
          MaterialPageRoute(
              builder: (_) => AddPrescriptionScreen(existing: p)),
        );
        if (result == true || result == 'deleted') {
          _load();
          widget.onPrescriptionChanged?.call();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUrgent
                ? color.withValues(alpha: 0.25)
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
                          color: Color(0xFF635A5A))),
                  const SizedBox(height: 3),
                  Text(
                    refillLabel(),
                    style: TextStyle(
                      fontSize: 11,
                      color: isRefillUrgent
                          ? const Color(0xFFF97316)
                          : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
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
            ],
          ],
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
    'Meditation': Color(0xFFFF6B6B),
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

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => AddActivityScreen(existing: a)),
        );
        if (result == true) {
          _load();
          widget.onActivityChanged?.call();
        }
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
                              color: Color(0xFF635A5A))),
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
    );
  }

  // ── Doctor row ─────────────────────────────────────────────────────────────

  Widget _buildDoctorRow(Doctor d) {
    const accent = Color(0xFF0EA5E9);
    final subtitle = <String>[];
    if (d.phone.isNotEmpty) subtitle.add(d.phone);
    final loc = [d.city, d.state].where((s) => s.isNotEmpty).join(', ');
    if (loc.isNotEmpty) subtitle.add(loc);

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<dynamic>(
          context,
          MaterialPageRoute(builder: (_) => AddDoctorScreen(existing: d)),
        );
        if (result == true || result == 'deleted') {
          _load();
          widget.onDoctorChanged?.call();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.medical_services_outlined,
                  color: accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.fullName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF635A5A)),
                  ),
                  if (d.specialty.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(d.specialty,
                        style: const TextStyle(
                            fontSize: 12,
                            color: accent,
                            fontWeight: FontWeight.w500)),
                  ],
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle.join(' · '),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Color(0xFFCBD5E1), size: 18),
          ],
        ),
      ),
    );
  }

  // ── Insurance row ──────────────────────────────────────────────────────────

  Widget _buildInsuranceRow(Insurance ins) {
    final typeColor = const {
      'Health': Color(0xFF059669),
      'Dental': Color(0xFF3B82F6),
      'Vision': Color(0xFF8B5CF6),
    }[ins.type] ?? const Color(0xFF059669);
    final typeIcon = const {
      'Health': Icons.health_and_safety_outlined,
      'Dental': Icons.sentiment_satisfied_outlined,
      'Vision': Icons.visibility_outlined,
    }[ins.type] ?? Icons.health_and_safety_outlined;

    final Color statusColor;
    final String? statusBadge;

    if (ins.isExpired) {
      statusColor = const Color(0xFFEF4444);
      statusBadge = 'Expired';
    } else if (ins.isExpiringSoon) {
      statusColor = const Color(0xFFF97316);
      statusBadge = 'Expiring Soon';
    } else if (ins.expirationDate != null) {
      statusColor = typeColor;
      statusBadge = 'Active';
    } else {
      statusColor = typeColor;
      statusBadge = null;
    }

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<dynamic>(
          context,
          MaterialPageRoute(builder: (_) => AddInsuranceScreen(existing: ins)),
        );
        if (result == true || result == 'deleted') {
          _load();
          widget.onInsuranceChanged?.call();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(typeIcon, color: typeColor, size: 18),
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
                        color: Color(0xFF635A5A)),
                  ),
                  if (ins.planName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(ins.planName,
                        style: TextStyle(
                            fontSize: 12,
                            color: typeColor,
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
            if (statusBadge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusBadge,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor)),
              ),
            ],
            const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1), size: 18),
          ],
        ),
      ),
    );
  }

  // ── Allergy row ────────────────────────────────────────────────────────────

  Widget _buildAllergyRow(Allergy a) {
    const color = Color(0xFFF59E0B);

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<dynamic>(
          context,
          MaterialPageRoute(builder: (_) => AddAllergyScreen(existing: a)),
        );
        if (result == true || result == 'deleted') {
          _load();
          widget.onAllergyChanged?.call();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.coronavirus, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF635A5A))),
                  if (a.reason != null) ...[
                    const SizedBox(height: 3),
                    Text(a.reason!,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1), size: 18),
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
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 14),
                  const SizedBox(width: 4),
                  Text('$count',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ],
              ),
              const SizedBox(height: 3),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 9,
                      color: color.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

