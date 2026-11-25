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
    with TickerProviderStateMixin {
  static const primaryMaroon = Color(0xFF7A2E3B);
  static const backgroundCream = Color(0xFFF6ECE2);

  late final AnimationController _c; // main timeline
  late final AnimationController _steam; // looping steam

  Timer? _timer;
  bool _started = false;

  static const double _total = 6.8;

  double _seg(double startSec, double endSec, Curve curve) {
    final t = _c.value * _total;
    if (t <= startSec) return 0.0;
    if (t >= endSec) return 1.0;
    return curve.transform((t - startSec) / (endSec - startSec));
  }

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_total * 1000).toInt()),
    );
    _steam = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    precacheImage(const AssetImage('assets/logo.png'), context)
        .whenComplete(() {
      if (!mounted) return;
      _c.forward();
      _steam.repeat();

      _timer = Timer(const Duration(milliseconds: 7600), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const RoleSelectionScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    _steam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      body: SafeArea(
        child: Center(
          // IMPORTANT: stage + tagline rendum AnimatedBuilder kulla
          child: AnimatedBuilder(
            animation: Listenable.merge([_c, _steam]),
            builder: (context, _) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  SizedBox(
                    width: 340,
                    height: 340,
                    child: _buildStage(),
                  ),
                  const SizedBox(height: 10),
                  _buildTagline(),
                  const Spacer(flex: 4),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // One idly widget
  Widget _idly(double size) {
    return CustomPaint(
      size: Size(size, size * 0.62),
      painter: _IdlyPainter(),
    );
  }

  Widget _buildStage() {
    final plateIn = _seg(0.0, 1.2, Curves.easeOutBack);
    final idly1 = _seg(1.0, 1.6, Curves.bounceOut);
    final idly2 = _seg(1.5, 2.1, Curves.bounceOut);
    final idly3 = _seg(2.0, 2.6, Curves.bounceOut);
    final idly4 = _seg(2.6, 3.4, Curves.bounceOut);
    final heartPop = _seg(3.3, 4.0, Curves.elasticOut);
    final vanish = _seg(3.9, 4.5, Curves.easeInBack);
    final logoPop = _seg(4.2, 5.4, Curves.elasticOut);
    final logoFade = _seg(4.2, 4.8, Curves.easeIn);

    final sceneScale = (1.0 - vanish).clamp(0.0, 1.0);
    final sceneOpacity = (1.0 - vanish).clamp(0.0, 1.0);

    const double idlySize = 70;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // ================= PLATE SCENE =================
        Opacity(
          opacity: sceneOpacity,
          child: Transform.scale(
            scale: sceneScale,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Plate
                Transform.translate(
                  offset: Offset(0, (1 - plateIn) * 180 + 40),
                  child: Opacity(
                    opacity: plateIn.clamp(0.0, 1.0),
                    child: CustomPaint(
                      size: const Size(250, 70),
                      painter: _PlatePainter(),
                    ),
                  ),
                ),

                // Steam
                Positioned(
                  top: 70,
                  child: Opacity(
                    opacity: idly3.clamp(0.0, 1.0),
                    child: CustomPaint(
                      size: const Size(160, 60),
                      painter: _SteamPainter(t: _steam.value),
                    ),
                  ),
                ),

                // 3 idlies
                _dropIdly(idly1, const Offset(-62, 30), idlySize),
                _dropIdly(idly2, const Offset(0, 22), idlySize),
                _dropIdly(idly3, const Offset(62, 30), idlySize),

                // 4th idly (separate, for others)
                _dropIdly(idly4, const Offset(0, -62), idlySize + 8),

                // Heart above the 4th idly
                Transform.translate(
                  offset: const Offset(0, -128),
                  child: Transform.scale(
                    scale: heartPop,
                    child: Opacity(
                      opacity: heartPop.clamp(0.0, 1.0),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: primaryMaroon,
                        size: 34,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ================= ELEPHANT LOGO =================
        Opacity(
          opacity: logoFade.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: logoPop,
            child: SizedBox(
              width: 240,
              height: 240,
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => const Icon(
                  Icons.favorite_rounded,
                  size: 100,
                  color: primaryMaroon,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dropIdly(double p, Offset target, double size) {
    final dy = (1 - p) * -170;
    return Transform.translate(
      offset: Offset(target.dx, target.dy + dy),
      child: Opacity(
        opacity: (p * 3).clamp(0.0, 1.0),
        child: _idly(size),
      ),
    );
  }

  // ================= TAGLINE (first version style) =================
  Widget _buildTagline() {
    // line 1: 5.0 - 5.7s
    final line1Fade = _seg(5.0, 5.7, Curves.easeIn);
    final line1Slide = _seg(5.0, 5.7, Curves.easeOutCubic);

    // line 2: 5.5 - 6.2s
    final line2Fade = _seg(5.5, 6.2, Curves.easeIn);
    final line2Slide = _seg(5.5, 6.2, Curves.easeOutCubic);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: line1Fade,
          child: Transform.translate(
            offset: Offset(0, (1 - line1Slide) * 14),
            child: Text(
              'Three idlies satisfies your hunger,',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14.5,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.3,
                color: primaryMaroon.withValues(alpha: 0.75),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Opacity(
          opacity: line2Fade,
          child: Transform.translate(
            offset: Offset(0, (1 - line2Slide) * 14),
            child: Text(
              'but the fourth idly is for others.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15.5,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: primaryMaroon,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================
//  PAINTERS
// =====================================================

class _IdlyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawOval(
      Rect.fromLTWH(w * 0.08, h * 0.80, w * 0.84, h * 0.20),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );

    final body = Path()
      ..moveTo(0, h * 0.88)
      ..quadraticBezierTo(0, h * 0.05, w * 0.5, h * 0.05)
      ..quadraticBezierTo(w, h * 0.05, w, h * 0.88)
      ..quadraticBezierTo(w * 0.5, h * 1.02, 0, h * 0.88)
      ..close();

    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF1E6D6)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFFD9C7AE),
    );

    canvas.drawArc(
      Rect.fromLTWH(w * 0.18, h * 0.14, w * 0.32, h * 0.30),
      math.pi * 1.05,
      math.pi * 0.55,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _PlatePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawOval(
      Rect.fromLTWH(w * 0.05, h * 0.38, w * 0.90, h * 0.62),
      Paint()..color = Colors.black.withValues(alpha: 0.10),
    );
    canvas.drawOval(
      Rect.fromLTWH(0, 0, w, h * 0.88),
      Paint()..color = const Color(0xFF7A2E3B),
    );
    canvas.drawOval(
      Rect.fromLTWH(w * 0.07, h * 0.08, w * 0.86, h * 0.66),
      Paint()..color = const Color(0xFF933B4A),
    );
    canvas.drawOval(
      Rect.fromLTWH(w * 0.12, h * 0.14, w * 0.76, h * 0.54),
      Paint()..color = const Color(0xFFF9F1E8),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _SteamPainter extends CustomPainter {
  final double t;
  _SteamPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      final x = size.width * (0.25 + i * 0.25);
      final yStart = size.height;
      final path = Path()..moveTo(x, yStart - p * size.height * 0.3);

      for (int s = 1; s <= 4; s++) {
        final y = yStart - p * size.height * 0.3 - s * (size.height / 5);
        final sway = math.sin((p + s * 0.3) * math.pi * 2) * 6;
        path.lineTo(x + sway, y);
      }

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF7A2E3B)
              .withValues(alpha: (math.sin(p * math.pi) * 0.35).clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SteamPainter old) => old.t != t;
}