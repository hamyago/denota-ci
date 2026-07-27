import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../main.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';

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
      AppNavigator.goToFeed();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding_seen') ?? false;
    if (!mounted) return;

    if (seen) {
      AppNavigator.goToLogin();
    } else {
      AppNavigator.goToOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
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
              child: const Center(
                child: Icon(Icons.star, color: AppColors.accent, size: 52),
              ),
            ),
            const SizedBox(height: 28),
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  TextSpan(text: 'De', style: TextStyle(color: Colors.white)),
                  TextSpan(text: 'No', style: TextStyle(color: AppColors.accent)),
                  TextSpan(text: 'Ta', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Détection de Nouveaux Talents',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: AppColors.grey400,
              ),
            ),
            const SizedBox(height: 80),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.accent.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
