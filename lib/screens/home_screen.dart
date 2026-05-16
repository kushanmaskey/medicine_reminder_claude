import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../tabs/prescriptions_tab.dart';
import '../tabs/appointments_tab.dart';
import '../tabs/vitals_tab.dart';
import 'login_screen.dart';
import 'add_prescription_screen.dart';
import 'add_appointment_screen.dart';
import 'add_vital_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _prescriptionsKey = GlobalKey<State>();
  final _appointmentsKey = GlobalKey<State>();
  final _vitalsKey = GlobalKey<State>();

  final List<String> _titles = ['Prescriptions', 'Appointments', 'Vitals'];

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
    if (_currentIndex == 0) {
      screen = const AddPrescriptionScreen();
    } else if (_currentIndex == 1) {
      screen = const AddAppointmentScreen();
    } else {
      screen = const AddVitalScreen();
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (result == true) setState(() {});
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

  Color get _fabColor {
    switch (_currentIndex) {
      case 1: return const Color(0xFF8B5CF6);
      case 2: return const Color(0xFF0D9488);
      default: return const Color(0xFF3B82F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Color(0xFF64748B)),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          PrescriptionsTab(key: _prescriptionsKey),
          AppointmentsTab(key: _appointmentsKey),
          VitalsTab(key: _vitalsKey),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDBEAFE),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description, color: Color(0xFF3B82F6)),
            label: 'Prescriptions',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: Color(0xFF8B5CF6)),
            label: 'Appointments',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon:
                Icon(Icons.monitor_heart, color: Color(0xFF0D9488)),
            label: 'Vitals',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddScreen,
        backgroundColor: _fabColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
