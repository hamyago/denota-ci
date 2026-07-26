// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../presentation/screens/auth/splash_screen.dart';
import '../../presentation/screens/auth/onboarding_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/auth/register_role_screen.dart';
import '../../presentation/screens/auth/otp_screen.dart';
import '../../presentation/screens/home/home_shell.dart';
import '../../presentation/screens/home/feed_screen.dart';
import '../../presentation/screens/home/notifications_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/profile/edit_profile_screen.dart';
import '../../presentation/screens/messaging/conversations_screen.dart';
import '../../presentation/screens/messaging/chat_screen.dart';
import '../../presentation/screens/search/discover_screen.dart';
import '../../presentation/screens/post/create_post_screen.dart';
import '../../presentation/screens/recruiter/recruiter_dashboard_screen.dart';
import '../../presentation/screens/payment/payment_screen.dart';

class AppRouter {
  static final _rootKey  = GlobalKey<NavigatorState>();
  static final _shellKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    redirect: (context, state) {
      final isAuth = Supabase.instance.client.auth.currentSession != null;
      final onAuthPages = [Routes.splash, Routes.onboarding, Routes.login,
        Routes.register, Routes.registerRole, Routes.otp].contains(state.matchedLocation);
      if (!isAuth && !onAuthPages) return Routes.login;
      if (isAuth && onAuthPages && state.matchedLocation != Routes.splash) return Routes.feed;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash,       builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.onboarding,   builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: Routes.login,        builder: (_, __) => const LoginScreen()),
      GoRoute(path: Routes.register,     builder: (_, __) => const RegisterScreen()),
      GoRoute(path: Routes.registerRole, builder: (_, __) => const RegisterRoleScreen()),
      GoRoute(path: Routes.otp,          builder: (ctx, s) => OtpScreen(phone: s.extra as String? ?? '')),

      ShellRoute(
        navigatorKey: _shellKey,
        builder: (ctx, s, child) => HomeShell(child: child),
        routes: [
          GoRoute(path: Routes.feed,          builder: (_, __) => const FeedScreen()),
          GoRoute(path: Routes.discover,      builder: (_, __) => const DiscoverScreen()),
          GoRoute(path: Routes.notifications, builder: (_, __) => const NotificationsScreen()),
          GoRoute(path: Routes.conversations, builder: (_, __) => const ConversationsScreen()),
          GoRoute(path: Routes.profile,       builder: (_, __) => const ProfileScreen()),
        ],
      ),

      // Écrans full-page hors shell
      GoRoute(path: Routes.profileView,   builder: (ctx, s) => ProfileScreen(userId: s.pathParameters['id'])),
      GoRoute(path: Routes.editProfile,   builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: Routes.chat,          builder: (ctx, s) => ChatScreen(conversationId: s.pathParameters['id'] ?? '')),
      GoRoute(path: Routes.createPost,    builder: (_, __) => const CreatePostScreen()),
      GoRoute(path: Routes.recruiterDash, builder: (_, __) => const RecruiterDashboardScreen()),
      GoRoute(path: Routes.payment,       builder: (ctx, s) => PaymentScreen(plan: s.extra as String? ?? 'athlete_premium')),
    ],
  );
}

class Routes {
  Routes._();
  static const splash        = '/';
  static const onboarding    = '/onboarding';
  static const login         = '/login';
  static const register      = '/register';
  static const registerRole  = '/register/role';
  static const otp           = '/otp';
  static const feed          = '/feed';
  static const discover      = '/discover';
  static const notifications = '/notifications';
  static const conversations = '/conversations';
  static const profile       = '/profile';
  static const profileView   = '/profile/:id';
  static const editProfile   = '/profile/edit';
  static const chat          = '/chat/:id';
  static const createPost    = '/post/create';
  static const recruiterDash = '/recruiter';
  static const payment       = '/payment';
}
