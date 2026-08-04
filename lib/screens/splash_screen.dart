import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'role_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeTextAnimation;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _progressAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.85, curve: Curves.easeInOutCubic),
    );

    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.04), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 50),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.82, 1.0, curve: Curves.easeInOut),
      ),
    );

    _fadeTextAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.65, 1.0, curve: Curves.easeIn),
    );

    _controller.forward();

    _timer = Timer(const Duration(milliseconds: 3200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const RoleSelectionScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryMaroon = Color(0xFF7A2E3B);
    const backgroundCream = Color(0xFFF6ECE2);

    return Scaffold(
      backgroundColor: backgroundCream,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: SizedBox(
                      width: 220,
                      height: 220,
                      child: CustomPaint(
                        painter: _LogoInterlockPainter(
                          progress: _progressAnimation.value,
                          maroonColor: primaryMaroon,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 36),
              FadeTransition(
                opacity: _fadeTextAnimation,
                child: Column(
                  children: [
                    Text(
                      'FOURTH IDLY',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4.0,
                        color: primaryMaroon,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Care you can taste',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.5,
                        color: primaryMaroon.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 4 petal outlines below were traced directly from the reference
/// logo image (pixel contour extraction), normalized to a unit radius,
/// with one petal's centroid rotated to angle 0. Rotating this single
/// petal by 0/90/180/270 degrees reproduces the exact emblem.
const List<Offset> _tracedPetalPoints = [
  Offset(-0.1198, -0.6024),
  Offset(-0.1789, -0.4321),
  Offset(-0.0237, -0.3100),
  Offset(0.1586, -0.2441),
  Offset(0.4138, -0.2448),
  Offset(0.5773, -0.2078),
  Offset(0.6830, -0.1417),
  Offset(0.7581, -0.0432),
  Offset(0.7807, 0.1201),
  Offset(0.7200, 0.3296),
  Offset(0.6149, 0.5018),
  Offset(0.4130, 0.7014),
  Offset(0.4438, 0.7966),
  Offset(0.5409, 0.8117),
  Offset(0.7701, 0.6069),
  Offset(0.9073, 0.3717),
  Offset(0.9778, 0.0124),
  Offset(0.9328, -0.2717),
  Offset(0.8594, -0.3498),
  Offset(0.7370, -0.3222),
  Offset(0.4882, -0.4185),
  Offset(0.1444, -0.4329),
];

class _LogoInterlockPainter extends CustomPainter {
  final double progress;
  final Color maroonColor;

  _LogoInterlockPainter({
    required this.progress,
    required this.maroonColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.2;

    // Soft blush-pink tint visible in the negative space between the
    // petals (sampled from the reference logo) — fades in as they join
    if (progress > 0.20) {
      final bgOpacity = ((progress - 0.20) / 0.80).clamp(0.0, 1.0);
      final bgPaint = Paint()
        ..color = const Color(0xFFE6D9D7).withValues(alpha: bgOpacity * 0.9)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawCircle(center, radius * 0.62, bgPaint);
    }

    final fillPaint = Paint()
      ..color = maroonColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Starts floating apart with extra spin, converges to 0 at progress = 1
    final double maxOffset = radius * 0.55;
    final double currentOffset = maxOffset * (1.0 - progress);
    final double extraSpin = (1.0 - progress) * (2 * math.pi);

    for (int i = 0; i < 4; i++) {
      final double baseAngle = i * (math.pi / 2);
      final double currentAngle = baseAngle + extraSpin;

      final double radialAngle = baseAngle + (math.pi / 4);
      final double dx = currentOffset * math.cos(radialAngle);
      final double dy = currentOffset * math.sin(radialAngle);

      canvas.save();
      canvas.translate(center.dx + dx, center.dy + dy);
      canvas.rotate(currentAngle);
      canvas.drawPath(_smoothPetalPath(radius), fillPaint);
      canvas.restore();
    }
  }

  /// Builds a smooth closed path through the traced petal points using
  /// quadratic Bezier curves through midpoints — this reproduces the
  /// smooth curved silhouette from the traced (slightly noisy) contour.
  Path _smoothPetalPath(double r) {
    final pts = _tracedPetalPoints
        .map((o) => Offset(o.dx * r, o.dy * r))
        .toList();
    // wrap first two points for closed-loop smoothing
    final wrapped = [...pts, pts[0], pts[1]];

    final path = Path()..moveTo(wrapped[0].dx, wrapped[0].dy);
    for (int i = 1; i < wrapped.length - 1; i++) {
      final mid = Offset(
        (wrapped[i].dx + wrapped[i + 1].dx) / 2,
        (wrapped[i].dy + wrapped[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(wrapped[i].dx, wrapped[i].dy, mid.dx, mid.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _LogoInterlockPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.maroonColor != maroonColor;
  }
}