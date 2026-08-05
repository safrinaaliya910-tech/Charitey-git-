// pending_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../main.dart';

class PendingVerificationScreen extends StatefulWidget {
  const PendingVerificationScreen({super.key});

  @override
  State<PendingVerificationScreen> createState() =>
      _PendingVerificationScreenState();
}

class _PendingVerificationScreenState extends State<PendingVerificationScreen>
    with SingleTickerProviderStateMixin {
  static const Color themeColor = Color(0xFFB56F76);

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final status = authProvider.currentUserModel?.status;

        if (status == 'approved' || status == 'active') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AuthWrapper()),
              (route) => false,
            );
          });
        }

        final bool isRejected = status == 'rejected';
        final bool isBlocked = status == 'blocked';
        final bool isProblem = isRejected || isBlocked;

        final Color accentColor = isProblem ? Colors.red.shade400 : themeColor;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: Stack(
            children: [
              // Decorative background accents — matches the style used
              // across the rest of the onboarding flow.
              Positioned(
                top: -110,
                right: -90,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -60,
                left: -100,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 440),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Animated pulsing icon for the "in progress" state;
                          // a static icon for rejected/blocked states.
                          SizedBox(
                            height: 110,
                            width: 110,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (!isProblem)
                                  AnimatedBuilder(
                                    animation: _pulseAnimation,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: _pulseAnimation.value,
                                        child: Container(
                                          width: 90,
                                          height: 90,
                                          decoration: BoxDecoration(
                                            color: accentColor.withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: accentColor.withValues(alpha: 0.25),
                                      width: 1.4,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accentColor.withValues(alpha: 0.15),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    isRejected
                                        ? Icons.close_rounded
                                        : (isBlocked
                                            ? Icons.block_rounded
                                            : Icons.hourglass_top_rounded),
                                    size: 40,
                                    color: accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Status chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              isRejected
                                  ? "REJECTED"
                                  : (isBlocked ? "BLOCKED" : "UNDER REVIEW"),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: accentColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          Text(
                            isRejected
                                ? "Verification Unsuccessful"
                                : (isBlocked ? "Account Blocked" : "Verification in Progress"),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2D3142),
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isRejected
                                ? "We couldn't verify your submitted document. Please contact support to re-submit a clearer copy of your license."
                                : (isBlocked
                                    ? "Your account has been blocked. Please contact support for more information."
                                    : "Our team is reviewing the license document you uploaded. This usually takes under 24 hours — we'll notify you the moment it's approved."),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              height: 1.6,
                            ),
                          ),

                          if (!isProblem) ...[
                            const SizedBox(height: 32),
                            _buildStepTracker(accentColor),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Small 3-step progress tracker: Submitted -> Under Review -> Approved.
  // Purely visual reassurance so the wait doesn't feel like a dead end.
  Widget _buildStepTracker(Color accentColor) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStepDot(filled: true, accentColor: accentColor),
            _buildStepLine(filled: true, accentColor: accentColor),
            _buildStepDot(filled: true, accentColor: accentColor, pulsing: true),
            _buildStepLine(filled: false, accentColor: accentColor),
            _buildStepDot(filled: false, accentColor: accentColor),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: 74,
              child: Text(
                "Submitted",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(
              width: 74,
              child: Text(
                "In Review",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: accentColor, fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(
              width: 74,
              child: Text(
                "Approved",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade400, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepDot({required bool filled, required Color accentColor, bool pulsing = false}) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: filled ? accentColor : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: filled ? accentColor : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: pulsing
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
    );
  }

  Widget _buildStepLine({required bool filled, required Color accentColor}) {
    return Container(
      width: 44,
      height: 2.4,
      color: filled ? accentColor : Colors.grey.shade300,
    );
  }
}