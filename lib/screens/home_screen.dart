import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../tabs/summary_tab.dart';
import '../tabs/prescriptions_tab.dart';
import '../tabs/appointments_tab.dart';
import '../tabs/vitals_tab.dart';
import '../tabs/activities_tab.dart';
import 'login_screen.dart';
import 'add_prescription_screen.dart';
import 'add_appointment_screen.dart';
import 'add_vital_screen.dart';
import 'add_activity_screen.dart';

const _gradientColors = [Color(0xFF0D9488), Color(0xFF0891B2)];
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
  }

  Future<void> _requestNotificationPermission() async {
    await NotificationService.requestPermission();
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
          padding: const EdgeInsets.all(10),
          child: Container(
            decoration: const BoxDecoration(
              gradient: _gradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.monitor_heart,
                color: Colors.white, size: 18),
          ),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => _gradient.createShader(
            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          ),
          blendMode: BlendMode.srcIn,
          child: Text(
            _titles[_currentIndex],
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ),
        actions: [
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
        indicatorColor: const Color(0xFF0D9488).withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Color(0xFF0D9488)),
            label: 'Summary',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description, color: Color(0xFF0D9488)),
            label: 'Prescriptions',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon:
                Icon(Icons.calendar_month, color: Color(0xFF0D9488)),
            label: 'Appointments',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon:
                Icon(Icons.monitor_heart, color: Color(0xFF0D9488)),
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
            color: const Color(0xFF0D9488).withValues(alpha: 0.45),
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
