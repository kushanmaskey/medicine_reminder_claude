import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

const _gradient = LinearGradient(
  colors: [Color(0xFF501513), Color(0xFF7A2420)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const _minPasswordLength = 8;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController     = TextEditingController();
  final _emailController    = TextEditingController();
  final _phoneController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();

  bool _loading           = false;
  bool _obscurePass       = true;
  bool _obscureConfirm    = true;
  String _sex             = 'Male';
  int _passwordLength     = 0;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(
        () => setState(() => _passwordLength = _passwordController.text.length));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _passwordMeetsLength => _passwordLength >= _minPasswordLength;

  String _sanitizeAuthError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('already registered') || lower.contains('already exists')) {
      return 'An account with this email already exists.';
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'Too many attempts. Please try again later.';
    }
    if (lower.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }
    if (lower.contains('password') && (lower.contains('6') || lower.contains('weak'))) {
      return 'Password does not meet security requirements.';
    }
    return 'Registration failed. Please try again.';
  }

  Future<void> _register() async {
    setState(() => _emailError = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final email = _emailController.text.trim();
    final error = await AuthService.register(
      email,
      _passwordController.text,
      _nameController.text.trim(),
      _sex,
      _phoneController.text.trim(),
    );

    if (error != null) {
      if (mounted) setState(() { _emailError = _sanitizeAuthError(error); _loading = false; });
      return;
    }

    // Supabase signs the user in automatically after signUp
    // (only if email confirmation is disabled in Supabase settings)
    final loggedIn = await AuthService.isLoggedIn();
    if (!loggedIn) {
      if (mounted) {
        setState(() {
          _emailError = 'Account created! Please check your email to confirm, then sign in.';
          _loading = false;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('session_login_time', DateTime.now().millisecondsSinceEpoch);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Gradient header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: _gradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
                28, MediaQuery.of(context).padding.top + 28, 28, 32),
            child: Row(
              children: [
                if (Navigator.canPop(context))
                  Tooltip(
                    message: 'Go back to sign in',
                    child: GestureDetector(
                      onTap: () => Navigator.canPop(context)
                            ? Navigator.pop(context)
                            : Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create Account',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start tracking your health today',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 28),

                    // Full name
                    TextFormField(
                      controller: _nameController,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      decoration:
                          _inputDecoration('Full Name', Icons.person_outline),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter your full name'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Sex selector
                    _buildSexSelector(),
                    const SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          _inputDecoration('Email', Icons.email_outlined),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Please enter a valid email address'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Phone
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration(
                          'Mobile Phone Number', Icons.phone_outlined),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter your mobile phone number';
                        }
                        final digits = v.replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 7) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePass,
                      decoration:
                          _inputDecoration('Password', Icons.lock_outline)
                              .copyWith(
                        suffixIcon: IconButton(
                          tooltip: _obscurePass
                              ? 'Show password'
                              : 'Hide password',
                          icon: Icon(
                            _obscurePass
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePass = !_obscurePass),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (v.length < _minPasswordLength) {
                          return 'Password must be at least $_minPasswordLength characters '
                              '(currently ${v.length})';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    _buildPasswordStrengthRow(),
                    const SizedBox(height: 16),

                    // Confirm password
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscureConfirm,
                      decoration: _inputDecoration(
                              'Confirm Password', Icons.lock_outline)
                          .copyWith(
                        suffixIcon: IconButton(
                          tooltip: _obscureConfirm
                              ? 'Show password'
                              : 'Hide password',
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey,
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) => v != _passwordController.text
                          ? 'Passwords do not match'
                          : null,
                    ),

                    const SizedBox(height: 20),

                    // Email-already-exists error
                    if (_emailError != null) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _emailError!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: _loading ? null : _gradient,
                          color:
                              _loading ? Colors.grey.shade200 : null,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: _loading
                              ? null
                              : [
                                  BoxShadow(
                                    color: const Color(0xFF501513)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: ElevatedButton(
                          onPressed: _loading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : const Text('Create Account',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sign-in link
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.canPop(context)
                            ? Navigator.pop(context)
                            : Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 14),
                            children: const [
                              TextSpan(text: 'Already have an account? '),
                              TextSpan(
                                text: 'Sign In',
                                style: TextStyle(
                                    color: Color(0xFF501513),
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Password strength row ──────────────────────────────────────────────────

  Widget _buildPasswordStrengthRow() {
    final segments = _minPasswordLength;
    final filled = _passwordLength.clamp(0, segments);
    final Color barColor;
    final String label;

    if (_passwordLength == 0) {
      barColor = Colors.grey.shade200;
      label = 'At least $_minPasswordLength characters required';
    } else if (_passwordLength < _minPasswordLength) {
      barColor = const Color(0xFFEF4444);
      label =
          '$_passwordLength of $_minPasswordLength characters — ${_minPasswordLength - _passwordLength} more needed';
    } else if (_passwordLength < 12) {
      barColor = const Color(0xFFF97316);
      label = 'Good — consider using 12+ characters for stronger security';
    } else {
      barColor = const Color(0xFF22C55E);
      label = 'Strong password';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Segment bar
        Row(
          children: List.generate(segments, (i) {
            final active = i < filled;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < segments - 1 ? 3 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: active ? barColor : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: _passwordLength == 0
                ? Colors.grey[400]
                : _passwordMeetsLength
                    ? (_passwordLength >= 12
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFF97316))
                    : const Color(0xFFEF4444),
          ),
        ),
      ],
    );
  }

  // ── Sex selector ───────────────────────────────────────────────────────────

  Widget _buildSexSelector() {
    const teal = Color(0xFF501513);
    const pink = Color(0xFF7A2420);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.wc_outlined, size: 16, color: teal),
            const SizedBox(width: 8),
            Text(
              'SEX',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[500],
                  letterSpacing: 0.6),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _SexChip(
              label: 'Male',
              icon: Icons.male,
              selected: _sex == 'Male',
              activeColor: teal,
              onTap: () => setState(() => _sex = 'Male'),
            ),
            const SizedBox(width: 12),
            _SexChip(
              label: 'Female',
              icon: Icons.female,
              selected: _sex == 'Female',
              activeColor: pink,
              onTap: () => setState(() => _sex = 'Female'),
            ),
          ],
        ),
      ],
    );
  }

  // ── Input decoration ───────────────────────────────────────────────────────

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF501513)),
      filled: true,
      fillColor: const Color(0xFFF8FFFE),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: Color(0xFF501513), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }
}

// ── Sex chip ────────────────────────────────────────────────────────────────

class _SexChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _SexChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: 'Select $label',
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: selected
                  ? activeColor.withValues(alpha: 0.1)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? activeColor.withValues(alpha: 0.6)
                    : Colors.grey.shade200,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 20,
                    color: selected ? activeColor : Colors.grey[400]),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? activeColor : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
