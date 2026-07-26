// lib/presentation/screens/auth/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    final session = supabase.auth.currentSession;
    if (session != null) {
      context.go(Routes.feed);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding_seen') ?? false;
    if (!mounted) return;

    context.go(seen ? Routes.login : Routes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Logo animé ──────────────────────────
            FadeInDown(
              duration: const Duration(milliseconds: 800),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Center(
                  child: _StarIcon(size: 52),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Wordmark ────────────────────────────
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              duration: const Duration(milliseconds: 700),
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                  children: [
                    TextSpan(text: 'De', style: TextStyle(color: Colors.white)),
                    TextSpan(text: 'No', style: TextStyle(color: AppColors.accent)),
                    TextSpan(text: 'Ta', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Tagline ─────────────────────────────
            FadeIn(
              delay: const Duration(milliseconds: 700),
              duration: const Duration(milliseconds: 700),
              child: const Text(
                'Détection de Nouveaux Talents',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: AppColors.grey400,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            const SizedBox(height: 80),

            // ── Loader ──────────────────────────────
            FadeIn(
              delay: const Duration(milliseconds: 1000),
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.accent.withOpacity(0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Étoile 4 branches stylisée
class _StarIcon extends StatelessWidget {
  final double size;
  const _StarIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _StarPainter(),
    );
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final ri = r * 0.38;

    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45 - 90) * (3.14159 / 180);
      final radius = i % 2 == 0 ? r : ri;
      final x = cx + radius * _cos(angle);
      final y = cy + radius * _sin(angle);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);

    // Centre blanc
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.18,
      Paint()..color = Colors.white,
    );
  }

  double _cos(double a) => _mathCos(a);
  double _sin(double a) => _mathSin(a);

  // ignore: non_constant_identifier_names
  static double _mathCos(double a) {
    return (a == 0)
        ? 1.0
        : (a == 3.14159 / 2)
            ? 0.0
            : (a == 3.14159)
                ? -1.0
                : (a == 3 * 3.14159 / 2)
                    ? 0.0
                    : _trig(a, true);
  }

  // ignore: non_constant_identifier_names
  static double _mathSin(double a) => _trig(a, false);

  static double _trig(double a, bool isCos) {
    // Approximation Taylor pour les angles utilisés
    final double x = isCos ? a : a;
    if (isCos) {
      double r = 1, t = 1;
      for (int i = 1; i <= 6; i++) {
        t *= -x * x / ((2 * i - 1) * (2 * i));
        r += t;
      }
      return r;
    } else {
      double r = x, t = x;
      for (int i = 1; i <= 6; i++) {
        t *= -x * x / ((2 * i) * (2 * i + 1));
        r += t;
      }
      return r;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
