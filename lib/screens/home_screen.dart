import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../tabs/summary_tab.dart';
import '../tabs/prescriptions_tab.dart';
import '../tabs/appointments_tab.dart';
import '../tabs/vitals_tab.dart';
import '../tabs/activities_tab.dart';
import '../tabs/doctors_tab.dart';
import 'biometric_lock_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'add_appointment_screen.dart';
import 'add_activity_screen.dart';

const _gradientColors = [Color(0xFF501513), Color(0xFF7A2420)];

const _defaultAvatarDefs = [
  (bg: Color(0xFF501513), icon: Icons.person),
  (bg: Color(0xFF3B82F6), icon: Icons.face),
  (bg: Color(0xFF8B5CF6), icon: Icons.sentiment_satisfied),
  (bg: Color(0xFFEF4444), icon: Icons.local_hospital),
  (bg: Color(0xFF7A2420), icon: Icons.favorite),
  (bg: Color(0xFFF59E0B), icon: Icons.star),
  (bg: Color(0xFF22C55E), icon: Icons.self_improvement),
  (bg: Color(0xFF14B8A6), icon: Icons.emoji_nature),
  (bg: Color(0xFFF97316), icon: Icons.sports_soccer),
  (bg: Color(0xFF6366F1), icon: Icons.music_note),
  (bg: Color(0xFF84CC16), icon: Icons.pets),
  (bg: Color(0xFF0EA5E9), icon: Icons.flight),
];
const _gradient = LinearGradient(
  colors: _gradientColors,
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String? _avatarType;
  int? _avatarIndex;
  Uint8List? _avatarImageBytes;
  Timer? _sessionTimer;

  final _summaryKey = GlobalKey<SummaryTabState>();
  final _prescriptionsKey = GlobalKey<PrescriptionsTabState>();
  final _appointmentsKey = GlobalKey<AppointmentsTabState>();
  final _vitalsKey = GlobalKey<VitalsTabState>();
  final _activitiesKey = GlobalKey<ActivitiesTabState>();
  final _doctorsKey = GlobalKey<DoctorsTabState>();

  final List<String> _titles = ['Summary', 'Doctors', 'Prescriptions', 'Appointments', 'Vitals', 'Activities'];

  static const _sessionDuration = Duration(hours: 1);

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    _loadAvatar();
    StorageService.decrementPillsIfNeeded();
    _startSessionTimer();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }

  Future<void> _startSessionTimer() async {
    final prefs = await SharedPreferences.getInstance();
    final loginMs = prefs.getInt('session_login_time');
    if (loginMs == null) return;

    final loginTime = DateTime.fromMillisecondsSinceEpoch(loginMs);
    final elapsed = DateTime.now().difference(loginTime);
    final remaining = _sessionDuration - elapsed;

    if (remaining <= Duration.zero) {
      // Already expired — sign out immediately
      _expireSession();
      return;
    }

    _sessionTimer = Timer(remaining, _expireSession);
  }

  Future<void> _expireSession() async {
    _sessionTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();

    final biometricEnabled = await BiometricService.isEnabled();
    final biometricAvailable = await BiometricService.isAvailable();

    if (biometricEnabled && biometricAvailable) {
      if (!mounted) return;
      final unlocked = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const BiometricLockScreen(),
        ),
      );
      if (unlocked == true) {
        // Reset session timer
        await prefs.setInt(
          'session_login_time',
          DateTime.now().millisecondsSinceEpoch,
        );
        _startSessionTimer();
      } else {
        // Biometric dismissed or failed — sign out
        await AuthService.logout();
        await prefs.remove('session_login_time');
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
      return;
    }

    // No biometric — standard sign-out with dialog
    await AuthService.logout();
    await prefs.remove('session_login_time');
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Session Expired'),
        content: const Text(
          'For your security, you have been signed out after 1 hour. Please sign in again to continue.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF501513),
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestNotificationPermission() async {
    await NotificationService.requestPermission();
  }

  Future<void> _loadAvatar() async {
    final data = await AuthService.getAvatarData();
    if (!mounted) return;
    Uint8List? imageBytes;
    if (data['type'] == 'custom' && data['image'] != null) {
      imageBytes = base64Decode(data['image'] as String);
    }
    setState(() {
      _avatarType = data['type'] as String?;
      _avatarIndex = data['index'] as int?;
      _avatarImageBytes = imageBytes;
    });
  }

  Future<void> _openAddScreen() async {
    // index 1 = Doctors
    if (_currentIndex == 1) {
      await _doctorsKey.currentState?.openAdd();
      setState(() {});
      return;
    }

    // index 2 = Prescriptions
    if (_currentIndex == 2) {
      await _prescriptionsKey.currentState?.openAdd();
      _summaryKey.currentState?.reload();
      setState(() {});
      return;
    }

    // index 4 = Vitals
    if (_currentIndex == 4) {
      final changed = await _vitalsKey.currentState?.openAdd() ?? false;
      if (changed) {
        _summaryKey.currentState?.reload();
        setState(() {});
      }
      return;
    }

    final Widget screen;
    if (_currentIndex == 3) {
      screen = const AddAppointmentScreen();
    } else {
      screen = const AddActivityScreen(); // index 5 = Activities
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (result == true) {
      if (_currentIndex == 3) _appointmentsKey.currentState?.reload();
      if (_currentIndex == 5) _activitiesKey.currentState?.reload();
      _summaryKey.currentState?.reload();
      setState(() {});
    }
  }

  Widget _buildAvatarButton() {
    if (_avatarType == 'custom' && _avatarImageBytes != null) {
      return CircleAvatar(
        radius: 16,
        backgroundImage: MemoryImage(_avatarImageBytes!),
      );
    }
    if (_avatarType == 'default' && _avatarIndex != null &&
        _avatarIndex! < _defaultAvatarDefs.length) {
      final def = _defaultAvatarDefs[_avatarIndex!];
      return CircleAvatar(
        radius: 16,
        backgroundColor: def.bg,
        child: Icon(def.icon, color: Colors.white, size: 16),
      );
    }
    return const CircleAvatar(
      radius: 16,
      backgroundColor: Color(0xFFE2E8F0),
      child: Icon(Icons.person_outline, color: Color(0xFF64748B), size: 18),
    );
  }

  Future<void> _openProfile() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    if (result == true) {
      _loadAvatar();
      _summaryKey.currentState?.reload();
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/icons/app_icon.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(
            color: Color(0xFF484141),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          Tooltip(
            message: 'Edit profile',
            child: GestureDetector(
              onTap: _openProfile,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildAvatarButton(),
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF64748B)),
            tooltip: 'Settings',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Color(0xFF64748B)),
            tooltip: 'Sign Out',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
            height: 2,
            decoration: const BoxDecoration(gradient: _gradient),
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          SummaryTab(
            key: _summaryKey,
            onTabChange: (i) => setState(() => _currentIndex = i),
            onVitalChanged: () => _vitalsKey.currentState?.reload(),
          ),
          DoctorsTab(key: _doctorsKey),
          PrescriptionsTab(key: _prescriptionsKey),
          AppointmentsTab(key: _appointmentsKey),
          VitalsTab(key: _vitalsKey, onDoctorAdded: () => _doctorsKey.currentState?.reload()),
          ActivitiesTab(key: _activitiesKey),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF501513).withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Color(0xFF501513)),
            label: 'Summary',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon:
                Icon(Icons.medical_services, color: Color(0xFF0EA5E9)),
            label: 'Doctors',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description, color: Color(0xFF501513)),
            label: 'Prescriptions',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon:
                Icon(Icons.calendar_month, color: Color(0xFF501513)),
            label: 'Appointments',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon:
                Icon(Icons.monitor_heart, color: Color(0xFF501513)),
            label: 'Vitals',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_walk_outlined),
            selectedIcon:
                Icon(Icons.directions_walk, color: Color(0xFF22C55E)),
            label: 'Activities',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? null
          : _GradientFAB(onPressed: _openAddScreen),
    );
  }
}

class _GradientFAB extends StatelessWidget {
  final VoidCallback onPressed;
  const _GradientFAB({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: _gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF501513).withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Tooltip(
          message: 'Add new item',
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white.withValues(alpha: 0.25),
            child: const Center(
              child: Icon(Icons.add, color: Colors.white, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}
