import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ringtone_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';

const _gradient = LinearGradient(
  colors: [Color(0xFF501513), Color(0xFF7A2420)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _soundName;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSoundName();
  }

  Future<void> _loadSoundName() async {
    final name = await RingtoneService.getSoundName();
    if (mounted) setState(() => _soundName = name);
  }

  Future<void> _changeSound() async {
    setState(() => _loading = true);
    final oldUri = await RingtoneService.getSoundUri();
    final result = await RingtoneService.pickRingtone();
    final newUri = result['uri'];

    if (newUri == null) {
      setState(() => _loading = false);
      return;
    }

    await NotificationService.deleteOldChannel(oldUri);
    await RingtoneService.saveSound(newUri, result['name']);
    await _rescheduleAll();

    if (mounted) {
      setState(() {
        _soundName = result['name'];
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notification sound updated to "${result['name'] ?? 'Custom'}"'),
          backgroundColor: const Color(0xFF501513),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _resetSound() async {
    final oldUri = await RingtoneService.getSoundUri();
    await NotificationService.deleteOldChannel(oldUri);
    await RingtoneService.clearSound();
    await _rescheduleAll();
    if (mounted) {
      setState(() => _soundName = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notification sound reset to system default'),
          backgroundColor: const Color(0xFF501513),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _rescheduleAll() async {
    final prescriptions = await StorageService.getPrescriptions();
    for (final p in prescriptions) {
      final time = p.notificationTime;
      if (time == null) continue;
      final notifId = NotificationService.idFromString(p.id);
      await NotificationService.cancelNotification(notifId);
      await NotificationService.scheduleDailyNotification(
        id: notifId,
        title: 'Medication Reminder',
        body: 'Time to take ${p.name}',
        time: time,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = Platform.isAndroid;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => _gradient.createShader(
            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          ),
          blendMode: BlendMode.srcIn,
          child: const Text(
            'Settings',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
            height: 2,
            decoration: const BoxDecoration(gradient: _gradient),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionHeader(title: 'Notifications'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: _gradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.music_note,
                        color: Colors.white, size: 20),
                  ),
                  title: const Text(
                    'Notification Sound',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: Text(
                    _soundName ?? 'System Default',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  trailing: isAndroid
                      ? (_loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF501513)),
                            )
                          : const Icon(Icons.chevron_right,
                              color: Color(0xFF94A3B8)))
                      : null,
                  onTap: isAndroid && !_loading ? _changeSound : null,
                ),
                if (_soundName != null) ...[
                  Divider(height: 1, indent: 72, color: Colors.grey.shade100),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: const SizedBox(width: 40),
                    title: Text(
                      'Reset to System Default',
                      style: TextStyle(color: Colors.red.shade400, fontSize: 14),
                    ),
                    onTap: _loading ? null : _resetSound,
                  ),
                ],
                if (!isAndroid) ...[
                  Divider(height: 1, indent: 72, color: Colors.grey.shade100),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.settings_outlined,
                          color: Color(0xFF3B82F6), size: 20),
                    ),
                    title: const Text(
                      'Change Sound in iOS Settings',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    subtitle: Text(
                      'Tap to open Notifications settings for this app',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    trailing: const Icon(Icons.open_in_new,
                        color: Color(0xFF94A3B8), size: 18),
                    onTap: () => openAppSettings(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Legal'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.gavel_outlined, color: Color(0xFF3B82F6), size: 20),
                  ),
                  title: const Text(
                    'Terms & Conditions',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: Text(
                    'Your rights and responsibilities using this app',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TermsScreen()),
                  ),
                ),
                Divider(height: 1, indent: 72, color: Colors.grey.shade100),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.policy_outlined, color: Color(0xFF3B82F6), size: 20),
                  ),
                  title: const Text(
                    'Privacy Policy',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: Text(
                    'How we collect and protect your data',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey[500],
        letterSpacing: 1.2,
      ),
    );
  }
}
