import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../presentation/screens/auth/splash_screen.dart';
import '../../presentation/screens/auth/onboarding_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/home/home_shell.dart';

// Navigation simple avec Navigator 1.0 — pas de dépendance app_links
class AppNavigator {
  static final navigatorKey = GlobalKey<NavigatorState>();

  static NavigatorState get navigator => navigatorKey.currentState!;

  static void goToFeed() => _replace(const HomeShell(child: FeedScreen()));
  static void goToLogin() => _replace(const LoginScreen());
  static void goToOnboarding() => _replace(const OnboardingScreen());
  static void goToRegister() => navigator.push(
    MaterialPageRoute(builder: (_) => const RegisterScreen()));

  static void _replace(Widget page) {
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => page),
      (_) => false,
    );
  }
}

// Routes en tant que constantes
class Routes {
  static const String splash        = '/';
  static const String onboarding    = '/onboarding';
  static const String login         = '/login';
  static const String register      = '/register';
  static const String registerRole  = '/register/role';
  static const String otp           = '/otp';
  static const String feed          = '/feed';
  static const String discover      = '/discover';
  static const String notifications = '/notifications';
  static const String conversations = '/conversations';
  static const String profile       = '/profile';
  static const String editProfile   = '/profile/edit';
  static const String createPost    = '/post/create';
  static const String recruiterDash = '/recruiter';
  static const String payment       = '/payment';
}

// Générateur de routes pour MaterialApp
class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case Routes.onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case Routes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case Routes.register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case Routes.feed:
      default:
        return MaterialPageRoute(
          builder: (_) => const HomeShell(child: FeedScreen()),
        );
    }
  }

  static String initialRoute() {
    final session = Supabase.instance.client.auth.currentSession;
    return session != null ? Routes.feed : Routes.splash;
  }
}
