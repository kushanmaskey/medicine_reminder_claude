import 'package:flutter/material.dart';

const _gradient = LinearGradient(
  colors: [Color(0xFF501513), Color(0xFF7A2420)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
            'Terms & Conditions',
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
          _TermsHeader(),
          SizedBox(height: 20),
          _TermsSection(
            number: '1',
            title: 'Acceptance of Terms',
            body:
                'By creating an account and checking the agreement box during registration, you confirm that you have read, understood, and agree to be bound by these Terms and our Privacy Policy.\n\n'
                'Your agreement is recorded along with your email address and the date and time of acceptance.\n\n'
                'If you do not agree to these Terms, you may not create an account or use the App.',
          ),
          _TermsSection(
            number: '2',
            title: 'About the App',
            body:
                'My Medical Wallet is a personal health organisation tool for tracking vitals, medications, appointments, activities, healthcare providers, insurance coverage, and allergies.\n\n'
                'The App is a personal organiser only. It is NOT a medical device, clinical system, or healthcare provider.',
          ),
          _TermsSection(
            number: '3',
            title: 'Personal Information We Collect',
            body:
                'By registering, you agree that we may collect and store:\n\n'
                '• Email address — for account creation and login\n'
                '• Mobile phone number — stored in your profile\n'
                '• Full name and biological sex — to personalise your experience\n'
                '• Personal health data — vitals, medications, appointments, activities, and doctor records you choose to enter\n'
                '• Insurance data — provider name, plan type, member ID / policy number, group number, coverage dates, copay, deductible, and contact info\n'
                '• Allergy data — allergy name, reaction type, and notes\n\n'
                'This data is NOT shared with, sold to, or disclosed to any third party for any commercial or advertising purpose.',
          ),
          _TermsSection(
            number: '4',
            title: 'Non-HIPAA Personal Health Data',
            body:
                'You acknowledge that:\n\n'
                '• The health data you enter is personal, self-reported information for your own reference\n'
                '• My Medical Wallet is NOT a HIPAA-covered entity\n'
                '• The App does not transmit your data to healthcare providers, insurers, or government agencies\n'
                '• Insurance information (policy numbers, group numbers, member IDs) is stored solely for your personal reference and is never shared with any insurer or third party\n'
                '• Your data is protected by Row Level Security — only you can access your records\n'
                '• You are responsible for the accuracy of data you enter',
          ),
          _TermsSection(
            number: '5',
            title: 'No Medical Advice or Recommendations',
            body:
                'THE APP DOES NOT PROVIDE MEDICAL ADVICE, DIAGNOSIS, OR TREATMENT RECOMMENDATIONS.\n\n'
                '• Health reference information is for general educational purposes only\n'
                '• The App does not recommend specific medications, treatments, or providers\n'
                '• Where available, the App redirects to government resources:\n'
                '  — MedlinePlus (medlineplus.gov)\n'
                '  — NPI Registry (npiregistry.cms.hhs.gov)\n\n'
                'Always consult a qualified healthcare professional before making any medical decision. In an emergency, call 911 immediately.',
          ),
          _TermsSection(
            number: '6',
            title: 'No Sale of User Data',
            body:
                'We do not and will not:\n\n'
                '• Sell your personal or health data to any third party\n'
                '• Share your data with advertisers or data brokers\n'
                '• Use your health data to train AI or machine learning models\n'
                '• Provide your data to insurance companies or employers',
          ),
          _TermsSection(
            number: '7',
            title: 'User Responsibilities',
            body:
                'You agree to:\n\n'
                '• Provide accurate registration information\n'
                '• Keep your password secure and confidential\n'
                '• Not share your account with others\n'
                '• Not use the App for any unlawful purpose\n'
                '• Not attempt to access another user\'s data\n'
                '• Notify us immediately of any suspected unauthorised access',
          ),
          _TermsSection(
            number: '8',
            title: 'Account Termination',
            body:
                'You may delete your account at any time by contacting medicalwallet473@gmail.com. All personal data will be permanently deleted within 30 days of your request.\n\n'
                'We reserve the right to suspend accounts that violate these Terms.',
          ),
          _TermsSection(
            number: '9',
            title: 'Disclaimer of Warranties',
            body:
                'The App is provided "as is" without warranties of any kind. We do not guarantee the App will be error-free, uninterrupted, or that health reference information is complete or current.',
          ),
          _TermsSection(
            number: '10',
            title: 'Limitation of Liability',
            body:
                'To the maximum extent permitted by law, My Medical Wallet shall not be liable for any indirect, incidental, or consequential damages arising from your use of the App, including reliance on any health information displayed.',
          ),
          _TermsSection(
            number: '11',
            title: 'Changes to These Terms',
            body:
                'We may update these Terms from time to time. The version number and effective date will be updated accordingly. Continued use of the App after changes constitutes acceptance of the revised Terms.',
          ),
          _TermsSection(
            number: '12',
            title: 'Contact',
            body: 'For questions about these Terms:\n\nmedicalwallet473@gmail.com',
          ),
          SizedBox(height: 8),
          _TermsFooter(),
        ],
      ),
    );
  }
}

class _TermsHeader extends StatelessWidget {
  const _TermsHeader();

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
          const Icon(Icons.gavel, color: Colors.white, size: 28),
          const SizedBox(height: 12),
          const Text(
            'My Medical Wallet — Terms & Conditions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Effective June 1, 2026  •  Version 1.0',
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

class _TermsSection extends StatelessWidget {
  final String number;
  final String title;
  final String body;
  const _TermsSection({required this.number, required this.title, required this.body});

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
                width: 26,
                height: 26,
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

class _TermsFooter extends StatelessWidget {
  const _TermsFooter();

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
