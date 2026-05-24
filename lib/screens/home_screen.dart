import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../tabs/summary_tab.dart';
import '../tabs/prescriptions_tab.dart';
import '../tabs/appointments_tab.dart';
import '../tabs/vitals_tab.dart';
import '../tabs/activities_tab.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'add_prescription_screen.dart';
import 'add_appointment_screen.dart';
import 'add_vital_screen.dart';
import 'add_activity_screen.dart';

const _gradientColors = [Color(0xFFE8607C), Color(0xFFF4A0B8)];

const _defaultAvatarDefs = [
  (bg: Color(0xFFE8607C), icon: Icons.person),
  (bg: Color(0xFF3B82F6), icon: Icons.face),
  (bg: Color(0xFF8B5CF6), icon: Icons.sentiment_satisfied),
  (bg: Color(0xFFEF4444), icon: Icons.local_hospital),
  (bg: Color(0xFFEC4899), icon: Icons.favorite),
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
  final _summaryKey = GlobalKey<SummaryTabState>();
  final _prescriptionsKey = GlobalKey<PrescriptionsTabState>();
  final _appointmentsKey = GlobalKey<AppointmentsTabState>();
  final _vitalsKey = GlobalKey<VitalsTabState>();
  final _activitiesKey = GlobalKey<ActivitiesTabState>();

  final List<String> _titles = ['Summary', 'Prescriptions', 'Appointments', 'Vitals', 'Activities'];

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    _loadAvatar();
    StorageService.decrementPillsIfNeeded();
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
    final Widget screen;
    if (_currentIndex == 1) {
      screen = const AddPrescriptionScreen();
    } else if (_currentIndex == 2) {
      screen = const AddAppointmentScreen();
    } else if (_currentIndex == 3) {
      screen = const AddVitalScreen();
    } else {
      screen = const AddActivityScreen();
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (result == true) {
      if (_currentIndex == 1) _prescriptionsKey.currentState?.reload();
      if (_currentIndex == 2) _appointmentsKey.currentState?.reload();
      if (_currentIndex == 3) _vitalsKey.currentState?.reload();
      if (_currentIndex == 4) _activitiesKey.currentState?.reload();
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
          ),
          PrescriptionsTab(key: _prescriptionsKey),
          AppointmentsTab(key: _appointmentsKey),
          VitalsTab(key: _vitalsKey),
          ActivitiesTab(key: _activitiesKey),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE8607C).withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Color(0xFFE8607C)),
            label: 'Summary',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description, color: Color(0xFFE8607C)),
            label: 'Prescriptions',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon:
                Icon(Icons.calendar_month, color: Color(0xFFE8607C)),
            label: 'Appointments',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon:
                Icon(Icons.monitor_heart, color: Color(0xFFE8607C)),
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
            color: const Color(0xFFE8607C).withValues(alpha: 0.45),
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
