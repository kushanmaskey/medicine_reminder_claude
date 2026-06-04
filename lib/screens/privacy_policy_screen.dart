import 'package:flutter/material.dart';

const _gradient = LinearGradient(
  colors: [Color(0xFF501513), Color(0xFF7A2420)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
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
            'Privacy Policy',
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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: const [
          _PolicyHeader(
            title: 'My Medical Wallet — Privacy Policy',
            subtitle: 'Effective date: June 1, 2026',
          ),
          SizedBox(height: 20),
          _PolicySection(
            number: '1',
            title: 'Introduction',
            body:
                'My Medical Wallet is a personal health management app that helps you track medications, appointments, vitals, activities, and healthcare providers.\n\nThis policy explains what data we collect, how we protect it, and your rights. By using the App you agree to these practices.',
          ),
          _PolicySection(
            number: '2',
            title: 'Information We Collect',
            body:
                'We collect only what you voluntarily enter:\n\n'
                '• Account: email address and password (stored as a hash — never plain text)\n'
                '• Profile: name, biological sex, avatar\n'
                '• Daily Vitals: blood pressure, blood sugar, weight, cholesterol\n'
                '• Misc Vitals: last period, mammogram, colonoscopy dates\n'
                '• Events / Procedures: event name, date, associated doctor\n'
                '• Medications: name, dosage, frequency, refill date, pill count, type\n'
                '• Appointments: doctor, date/time, location, notes\n'
                '• Activities: type, distance, duration, date\n'
                '• Doctors: name, specialty, phone, address, NPI number\n'
                '• Notes attached to any record',
          ),
          _PolicySection(
            number: '3',
            title: 'How We Use Your Information',
            body:
                'Your data is used solely to power the App\'s features — displaying records, sending local reminders, and personalising your health summary.\n\n'
                'We do NOT:\n'
                '• Sell your data to any third party\n'
                '• Use your data for advertising\n'
                '• Share data with insurers or employers\n'
                '• Use health data to train AI models',
          ),
          _PolicySection(
            number: '4',
            title: 'How We Store and Protect Your Data',
            body:
                'All data is stored in Supabase (supabase.com):\n\n'
                '• Encrypted in transit over HTTPS/TLS\n'
                '• Encrypted at rest on Supabase\'s servers\n'
                '• Protected by Row Level Security — only you can access your data\n'
                '• Authenticated with industry-standard JWT tokens',
          ),
          _PolicySection(
            number: '5',
            title: 'Sensitive Health Data',
            body:
                'The App handles sensitive health data including menstrual records, medication history, and clinical measurements. All health data is:\n\n'
                '• Never shared with any third party\n'
                '• Never used for any purpose other than displaying it back to you\n'
                '• Deletable by you at any time from within the App\n\n'
                'This App is a personal organiser. It is not a HIPAA-covered entity and is not intended as a medical device or clinical record system.',
          ),
          _PolicySection(
            number: '6',
            title: 'Health Information Disclaimer',
            body:
                'Health reference information shown in the App (BP ranges, blood sugar classifications, screening schedules) is for general informational purposes only and is NOT a substitute for professional medical advice, diagnosis, or treatment.\n\n'
                'Always consult a qualified healthcare provider. In an emergency, call 911 immediately.\n\n'
                'Reference links open MedlinePlus (medlineplus.gov), a U.S. National Library of Medicine service whose content is in the public domain.',
          ),
          _PolicySection(
            number: '7',
            title: 'Third-Party Services',
            body:
                '• Supabase (supabase.com) — database and authentication\n'
                '• NPI Registry (npiregistry.cms.hhs.gov) — public doctor lookup; search terms only, no personal data transmitted\n'
                '• MedlinePlus (medlineplus.gov) — links open in your browser; no data shared\n\n'
                'We do not use analytics, advertising, or tracking SDKs.',
          ),
          _PolicySection(
            number: '8',
            title: 'Notifications',
            body:
                'With your permission, the App sends local push notifications for medication reminders and appointments. These are processed entirely on your device and are never routed through an external server.',
          ),
          _PolicySection(
            number: '9',
            title: 'Data Retention',
            body:
                'Your data stays in the App until you delete it. The App automatically removes activity records older than 7 days. All other records are kept until you delete them manually or request account deletion.',
          ),
          _PolicySection(
            number: '10',
            title: 'Your Rights',
            body:
                '• Access — view all your data in the App at any time\n'
                '• Correction — edit any record by tapping it\n'
                '• Deletion — delete records in the App, or contact us for full account deletion\n'
                '• Portability — contact us to request a data export\n\n'
                'Account deletion requests are fulfilled within 30 days.',
          ),
          _PolicySection(
            number: '11',
            title: 'California Residents (CCPA)',
            body:
                'California residents have the right to know what data we collect, request deletion, and opt out of data sales. We do not sell personal information. Contact us at the email below to exercise your rights.',
          ),
          _PolicySection(
            number: '12',
            title: "Children's Privacy",
            body:
                'This App is not directed to children under 13. We do not knowingly collect data from children under 13. Contact us if you believe a child has provided us with data and we will delete it promptly.',
          ),
          _PolicySection(
            number: '13',
            title: 'Changes to This Policy',
            body:
                'We may update this policy from time to time. Continued use of the App after changes constitutes acceptance of the updated policy.',
          ),
          _PolicySection(
            number: '14',
            title: 'Contact Us',
            body:
                'For privacy questions or data deletion requests:\n\nmedicalwallet473@gmail.com\n\nWe aim to respond within 14 business days.',
          ),
          SizedBox(height: 8),
          _PolicyFooter(),
        ],
      ),
    );
  }
}

class _PolicyHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _PolicyHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _gradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.policy, color: Colors.white, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String number;
  final String title;
  final String body;
  const _PolicySection({required this.number, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  gradient: _gradient,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF484141),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyFooter extends StatelessWidget {
  const _PolicyFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Text(
        'My Medical Wallet is an independent application and is not affiliated with, endorsed by, or connected to any government agency, healthcare provider, insurance company, or medical institution.',
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey[400],
          fontStyle: FontStyle.italic,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
