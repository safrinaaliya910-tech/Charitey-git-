//travel_agency_login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'travel_agency_register_screen.dart';
import 'home_screen.dart';


class TravelAgencyLoginScreen extends StatefulWidget {
  const TravelAgencyLoginScreen({super.key});


  @override
  State<TravelAgencyLoginScreen> createState() => _TravelAgencyLoginScreenState();
}


class _TravelAgencyLoginScreenState extends State<TravelAgencyLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();


  // The Dusty Rose Theme Color
  final Color themeColor = const Color(0xFFB56F76);


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }


  // --- LOGIC REMAINS EXACTLY THE SAME ---
  void _login() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);


    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();


    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both email and password.')),
      );
      return;
    }


    bool success = await authProvider.signInWithRole(email, password, 'travel_agency');


    if (!context.mounted) return;


    if (success) {
      // Returning users go straight to the Home Screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } else {
      // Show the specific reason (e.g. "linked to Google") when available,
      // otherwise fall back to the generic message.
      final message = authProvider.lastError ??
          'Login failed. Please check your credentials.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);


    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Soft off-white background
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // --- Background Decorative Blobs ---
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: -120,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -50,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),


          // --- Main Content (Locked to Single View) ---
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(flex: 2),
                         
                          // Title Area
                          const Text(
                            'Agency Login',
                            style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Safe Food Logistics",
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 40),
                         
                          _buildInputField(hint: 'Agency E-mail ID', icon: Icons.email_outlined, controller: _emailController, keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 16),
                          _buildInputField(hint: 'Password', icon: Icons.lock_outline_rounded, controller: _passwordController, isPassword: true),
                          const SizedBox(height: 12),


                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                // Forgot password logic placeholder
                              },
                              child: Text(
                                'Forget Password?',
                                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),


                          // MAIN LOGIN BUTTON
                          ElevatedButton(
                            onPressed: authProvider.isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              elevation: 4,
                              shadowColor: themeColor.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: authProvider.isLoading
                                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                : const Text(
                                    'LOG IN',
                                    style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                  ),
                          ),
                          const SizedBox(height: 24),


                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text('OR', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                              ),
                              Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                            ],
                          ),
                          const SizedBox(height: 24),


                          // REAL UI GOOGLE BUTTON
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              elevation: 2,
                              shadowColor: Colors.black12,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: () async {
                              bool success = await authProvider.signInWithGoogle(expectedRole: 'travel_agency');
                              if (!context.mounted) return;


                              if (success) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                                  (route) => false,
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Google sign in failed. Please try again.")),
                                );
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.network(
                                  'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/24px-Google_%22G%22_logo.svg.png',
                                  height: 24,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, color: Colors.red, size: 30),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  "Continue with Google",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                         
                          const Spacer(flex: 3),


                          // BOTTOM REGISTER LINK
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => const TravelAgencyRegisterScreen()),
                                  );
                                },
                                child: Text(
                                  'Sign up',
                                  style: TextStyle(fontSize: 15, color: themeColor, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  // --- FLOATING TEXT FIELD UI ---
  Widget _buildInputField({required String hint, required IconData icon, required TextEditingController controller, bool isPassword = false, TextInputType keyboardType = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }
}