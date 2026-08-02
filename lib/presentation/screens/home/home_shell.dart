import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../main.dart';
import 'tiktok_feed_screen.dart';
import '../search/discover_screen.dart';
import '../messaging/conversations_screen.dart';
import '../home/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../recruiter/recruiter_dashboard_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../auth/account_status_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  String _role = 'athlete';
  String _status = 'active';
  bool _roleLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid != null) {
      try {
        final data = await supabase
            .from('profiles')
            .select('role, status')
            .eq('id', uid)
            .maybeSingle();
        if (data != null && mounted) {
          setState(() {
            _role = data['role'] as String? ?? 'athlete';
            _status = data['status'] as String? ?? 'active';
            _roleLoaded = true;
          });
          return;
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _roleLoaded = true);
  }

  List<Widget> get _screens {
    switch (_role) {
      case 'recruiter':
        return const [
          RecruiterDashboardScreen(),
          DiscoverScreen(),
          ConversationsScreen(),
          NotificationsScreen(),
          ProfileScreen(),
        ];
      case 'admin':
        return const [
          AdminDashboardScreen(),
          DiscoverScreen(),
          ConversationsScreen(),
          NotificationsScreen(),
          ProfileScreen(),
        ];
      default: // athlete, institution, sponsor, expert
        return const [
          TikTokFeedScreen(),
          DiscoverScreen(),
          ConversationsScreen(),
          NotificationsScreen(),
          ProfileScreen(),
        ];
    }
  }

  List<NavigationDestination> get _destinations {
    final homeLabel = _role == 'recruiter'
        ? 'Dashboard'
        : _role == 'admin'
            ? 'Admin'
            : 'Accueil';
    final homeIcon = _role == 'recruiter'
        ? Icons.dashboard_outlined
        : _role == 'admin'
            ? Icons.admin_panel_settings_outlined
            : Icons.home_outlined;
    final homeSelectedIcon = _role == 'recruiter'
        ? Icons.dashboard
        : _role == 'admin'
            ? Icons.admin_panel_settings
            : Icons.home;

    return [
      NavigationDestination(
        icon: Icon(homeIcon),
        selectedIcon: Icon(homeSelectedIcon, color: AppColors.primary),
        label: homeLabel,
      ),
      const NavigationDestination(
        icon: Icon(Icons.search_outlined),
        selectedIcon: Icon(Icons.search, color: AppColors.primary),
        label: 'Découvrir',
      ),
      const NavigationDestination(
        icon: Icon(Icons.chat_bubble_outline),
        selectedIcon: Icon(Icons.chat_bubble, color: AppColors.primary),
        label: 'Messages',
      ),
      const NavigationDestination(
        icon: Icon(Icons.notifications_outlined),
        selectedIcon: Icon(Icons.notifications, color: AppColors.primary),
        label: 'Alertes',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outlined),
        selectedIcon: Icon(Icons.person, color: AppColors.primary),
        label: 'Profil',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!_roleLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    // Compte non validé / bloqué : on n'affiche pas l'app, mais un écran
    // d'attente ou de blocage (avec possibilité de re-vérifier / déconnexion).
    if (_status != 'active') {
      return AccountStatusScreen(
        status: _status,
        onRefresh: () async {
          setState(() => _roleLoaded = false);
          await _loadRole();
        },
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.grey200, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          backgroundColor: AppColors.white,
          indicatorColor: AppColors.primaryBg,
          destinations: _destinations,
        ),
      ),
    );
  }
}
