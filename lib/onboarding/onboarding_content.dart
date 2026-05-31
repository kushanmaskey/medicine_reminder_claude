class OnboardingPage {
  final String title;
  final String body;
  final String emoji;

  const OnboardingPage({
    required this.title,
    required this.body,
    required this.emoji,
  });
}

const List<OnboardingPage> kOnboardingPages = [
  OnboardingPage(
    emoji: '👋',
    title: 'Welcome to My Medical Wallet',
    body:
        'Your health, your records — always with you.\n\n'
        'Create your account using your email address. For your security, '
        'email verification may be required before you can access the app.',
  ),
  OnboardingPage(
    emoji: '📋',
    title: 'Your Summary',
    body:
        'The first thing you\'ll see when you open the app is your personal '
        'Summary — an at-a-glance view of everything that matters.\n\n'
        'It surfaces the latest entries from each section: prescriptions, '
        'upcoming appointments, recent vitals, logged activities, and your '
        'doctors list — all in one place, so nothing slips through the cracks.',
  ),
  OnboardingPage(
    emoji: '🩺',
    title: 'Doctors',
    body:
        'Build your own personal doctors list. Add your primary care physician, '
        'specialists, and any other healthcare providers you visit.\n\n'
        'Storing your doctors here lets you link them to your prescriptions '
        'and keep all your care in one organised place.',
  ),
  OnboardingPage(
    emoji: '💊',
    title: 'Prescriptions',
    body:
        'Keep track of every medication you take. Add prescriptions from your '
        'doctors — including who prescribed it, your daily reminder time, and '
        'automatic refill date notifications based on your pill count.\n\n'
        'You can also maintain a separate list of over-the-counter medications. '
        'Everything is organised into two tabs: Prescribed and Over the Counter.',
  ),
  OnboardingPage(
    emoji: '📅',
    title: 'Appointments',
    body:
        'Never miss a medical appointment again. Create appointments with your '
        'doctor\'s name, location, and notes.\n\n'
        'Set one or more custom alerts to remind you ahead of time — whether '
        'that\'s a day before or an hour before.',
  ),
  OnboardingPage(
    emoji: '❤️',
    title: 'Vitals',
    body:
        'Track the health numbers that matter to you. Based on the gender you '
        'select during registration, you\'ll see the appropriate vital '
        'categories — including daily vitals (blood pressure, blood sugar, '
        'cholesterol, weight), monthly tracking, and miscellaneous health events.\n\n'
        'Each entry includes a colour-coded recommendation so you always know '
        'where you stand.',
  ),
  OnboardingPage(
    emoji: '🏃',
    title: 'Activities',
    body:
        'Log your daily physical activities to build a picture of your overall '
        'health over time.\n\n'
        'Whether it\'s a walk, a workout, or any other activity, tracking it '
        'here helps you and your care team see the full story.',
  ),
  OnboardingPage(
    emoji: '🔒',
    title: 'A Few More Things',
    body:
        '🔔  Notification sound — Reminders use your phone\'s default '
        'notification ringtone, which you can change in your phone\'s settings.\n\n'
        '🖼️  Avatar — Head to your profile to choose a personal avatar that '
        'makes the app feel like yours.\n\n'
        '🛡️  Your privacy — My Medical Wallet stores only basic, '
        'non-HIPAA-regulated health information. Your data is encrypted, '
        'protected by row-level security, and never sold or shared with '
        'third parties.',
  ),
];
