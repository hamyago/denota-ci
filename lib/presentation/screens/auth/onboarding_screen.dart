// lib/presentation/screens/auth/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:animate_do/animate_do.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  final _slides = const [
    _OnboardingSlide(
      emoji: '🌟',
      title: 'Révèle ton talent',
      subtitle: 'Crée ton profil sportif, publie tes meilleures vidéos et fais-toi remarquer par les recruteurs de toute l\'Afrique de l\'Ouest.',
      color: AppColors.primary,
      bgColor: AppColors.primaryBg,
    ),
    _OnboardingSlide(
      emoji: '🏆',
      title: 'Sois évalué par des experts',
      subtitle: 'Des coaches et scouts certifiés notent tes performances. Ton Talent Score™ évolue en temps réel et te classe parmi les meilleurs.',
      color: AppColors.accent,
      bgColor: AppColors.accentLight,
    ),
    _OnboardingSlide(
      emoji: '🤝',
      title: 'Connecte avec les recruteurs',
      subtitle: 'Clubs professionnels, agents et sponsors te découvrent sur DeNoTa. Ta prochaine opportunité commence ici, en Côte d\'Ivoire.',
      color: AppColors.blue,
      bgColor: AppColors.blueBg,
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (!mounted) return;
    context.go(Routes.login);
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip ──────────────────────────────────
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text(
                    'Passer',
                    style: TextStyle(
                      color: AppColors.grey500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            // ── Pages ─────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _slides.length,
                itemBuilder: (context, i) => _slides[i],
              ),
            ),

            // ── Dots + Button ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: _controller,
                    count: _slides.length,
                    effect: ExpandingDotsEffect(
                      activeDotColor: _slides[_page].color,
                      dotColor: AppColors.grey200,
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _slides[_page].color,
                    ),
                    child: Text(
                      _page == _slides.length - 1
                          ? 'Commencer maintenant'
                          : 'Suivant',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_page == _slides.length - 1)
                    TextButton(
                      onPressed: () => context.go(Routes.login),
                      child: const Text(
                        'J\'ai déjà un compte',
                        style: TextStyle(
                          color: AppColors.grey500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final Color bgColor;

  const _OnboardingSlide({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icône
          FadeInDown(
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 72)),
              ),
            ),
          ),
          const SizedBox(height: 48),

          // Titre
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Subtitle
          FadeInUp(
            delay: const Duration(milliseconds: 350),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: AppColors.grey500,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
