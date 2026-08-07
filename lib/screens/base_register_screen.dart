//base_register_screen
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'donor_login_screen.dart';
import 'ngo_login_screen.dart';
import 'volunteer_login_screen.dart'; // <-- NEW IMPORT
import 'profile_setup_screen.dart';

class BaseRegisterScreen extends StatefulWidget {
  final String role; // 'donor', 'ngo', 'travel_agency', or 'volunteer'
  const BaseRegisterScreen({super.key, required this.role});

  @override
  State<BaseRegisterScreen> createState() => _BaseRegisterScreenState();
}

class _BaseRegisterScreenState extends State<BaseRegisterScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  late AnimationController _rotationController;
  static const Color themeColor = Color(0xFF8C4149);

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get roleConfig {
    switch (widget.role) {
      case 'ngo':
        return {
          'title': 'Create Receiver Account',
          'subtitle': 'We\'re here to help you get support.',
          'nameHint': 'Enter NGO name',
          'nameIcon': Icons.domain_rounded,
        };
      case 'travel_agency':
        return {
          'title': 'Create Agency Account',
          'subtitle': 'Join our logistics network to help out.',
          'nameHint': 'Enter name',
          'nameIcon': Icons.local_shipping_outlined,
        };
      // 👇 NEW: VOLUNTEER CONFIG 👇
      case 'volunteer':
        return {
          'title': 'Become a Kindness Champion',
          'subtitle': 'Help transport donations and make an impact.',
          'nameHint': 'Enter full name',
          'nameIcon': Icons.directions_car_rounded,
        };
      case 'donor':
      default:
        return {
          'title': 'Create Your Account',
          'subtitle': 'We\'re here to help you make a difference.',
          'nameHint': 'Enter full name',
          'nameIcon': Icons.person_outline_rounded,
        };
    }
  }

  /// Checks password strength:
  /// - At least 6 characters
  /// - At least one special character
  bool _isStrongPassword(String password) {
    if (password.length < 6) return false;
    final specialCharRegex = RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=~`\[\]\\/;]');
    return specialCharRegex.hasMatch(password);
  }

  void _register() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    String name = _nameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields to sign up.')),
      );
      return;
    }

    if (!_isStrongPassword(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Weak password. Use at least 6 characters with 1 special character.',
          ),
        ),
      );
      return;
    }

    bool success = await authProvider.signUp(
      name: name,
      email: email,
      password: password,
      phone: '',
      location: '',
      role: widget.role,
    );

    if (!context.mounted) return;

    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => ProfileSetupScreen(role: widget.role)),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This email is already registered. Please log in instead.',
          ),
        ),
      );
    }
  }

  void _googleSignUp() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool success = await authProvider.signInWithGoogle(role: widget.role);
    if (!context.mounted) return;

    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => ProfileSetupScreen(role: widget.role)),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Google sign up failed.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final size = MediaQuery.of(context).size;
    final config = roleConfig;

    return Scaffold(
      backgroundColor: themeColor,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          SizedBox(
            height: size.height * 0.16,
            child: AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(
                        math.cos(_rotationController.value * 2 * math.pi),
                        math.sin(_rotationController.value * 2 * math.pi),
                      ),
                      end: Alignment(
                        math.cos((_rotationController.value + 0.5) * 2 * math.pi),
                        math.sin((_rotationController.value + 0.5) * 2 * math.pi),
                      ),
                      colors: const [
                        Color(0xFF8C4149),
                        Color(0xFF7A3540),
                        Color(0xFFA05060),
                        Color(0xFF8C4149),
                      ],
                    ),
                  ),
                  child: child,
                );
              },
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        'Back',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(36),
                  topRight: Radius.circular(36),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              children: [
                                Text(
                                  config['title'],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E1E1E),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  config['subtitle'],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildInputField(
                                  hint: config['nameHint'],
                                  icon: config['nameIcon'],
                                  controller: _nameController,
                                ),
                                const SizedBox(height: 10),
                                _buildInputField(
                                  hint: 'Enter email',
                                  icon: Icons.email_outlined,
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 10),
                                _buildPasswordField(),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Min 6 characters, at least 1 special character.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Container(
                                  width: double.infinity,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                        color: themeColor.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: authProvider.isLoading ? null : _register,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                    child: Ink(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFE8828A), Color(0xFF8C4149)],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Container(
                                        alignment: Alignment.center,
                                        child: authProvider.isLoading
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2.5,
                                                ),
                                              )
                                            : const Text(
                                                'Get Started',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Row(
                                    children: [
                                      Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Text(
                                          'Sign up with',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                        ),
                                      ),
                                      Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: OutlinedButton(
                                    onPressed: authProvider.isLoading ? null : _googleSignUp,
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      backgroundColor: Colors.white,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Image.network(
                                          'https://developers.google.com/identity/images/g-logo.png',
                                          height: 24,
                                          width: 24,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Icon(Icons.g_mobiledata, color: Colors.red, size: 24);
                                          },
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          "Continue with Google",
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Already have an account? ",
                                      style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        if (widget.role == 'ngo') {
                                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const NgoLoginScreen()));
                                        } else if (widget.role == 'volunteer') {
                                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const VolunteerLoginScreen()));
                                        } else {
                                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DonorLoginScreen()));
                                        }
                                      },
                                      child: const Text(
                                        'Log In',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: themeColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        decoration: InputDecoration(
          hintText: 'Enter password',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(Icons.lock_outline_rounded, color: Colors.grey.shade400, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: Colors.grey.shade400,
              size: 20,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }
}