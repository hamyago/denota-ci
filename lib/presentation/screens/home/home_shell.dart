// lib/presentation/screens/home/home_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';

class HomeShell extends StatelessWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  int _locationToIndex(String location) {
    if (location.startsWith('/feed'))          return 0;
    if (location.startsWith('/discover'))      return 1;
    if (location.startsWith('/conversations')) return 2;
    if (location.startsWith('/notifications')) return 3;
    if (location.startsWith('/profile'))       return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go(Routes.feed);          break;
      case 1: context.go(Routes.discover);      break;
      case 2: context.go(Routes.conversations); break;
      case 3: context.go(Routes.notifications); break;
      case 4: context.go(Routes.profile);       break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _locationToIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.grey200, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => _onTap(context, i),
          backgroundColor: AppColors.white,
          indicatorColor: AppColors.primaryBg,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppColors.primary),
              label: 'Accueil',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search, color: AppColors.primary),
              label: 'Découvrir',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble, color: AppColors.primary),
              label: 'Messages',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications, color: AppColors.primary),
              label: 'Alertes',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outlined),
              selectedIcon: Icon(Icons.person, color: AppColors.primary),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FEED SCREEN
// ─────────────────────────────────────────────────────────────
// lib/presentation/screens/home/feed_screen.dart
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            style: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700),
            children: [
              TextSpan(text: 'De', style: TextStyle(color: AppColors.ink)),
              TextSpan(text: 'No', style: TextStyle(color: AppColors.primary)),
              TextSpan(text: 'Ta', style: TextStyle(color: AppColors.accent)),
            ],
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.add_box_outlined), onPressed: () {}),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 8,
        itemBuilder: (_, i) => const _PostCard(),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(radius: 20, backgroundColor: AppColors.primaryBg,
                    child: const Text('KK', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13))),
                const SizedBox(width: 10),
                const Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Koné Kader', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('Football · Abidjan', style: TextStyle(color: AppColors.grey500, fontSize: 12)),
                  ],
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(8)),
                  child: const Text('87 ⭐', style: TextStyle(color: AppColors.accentDark, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          // Thumbnail
          Container(
            height: 200,
            color: AppColors.ink,
            child: const Center(child: Icon(Icons.play_circle_fill, color: AppColors.accent, size: 56)),
          ),
          // Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.favorite_border, size: 22, color: AppColors.grey500),
                const SizedBox(width: 4),
                const Text('124', style: TextStyle(fontSize: 13, color: AppColors.grey500)),
                const SizedBox(width: 16),
                const Icon(Icons.chat_bubble_outline, size: 22, color: AppColors.grey500),
                const SizedBox(width: 4),
                const Text('18', style: TextStyle(fontSize: 13, color: AppColors.grey500)),
                const Spacer(),
                const Icon(Icons.share_outlined, size: 22, color: AppColors.grey500),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DISCOVER SCREEN
// ─────────────────────────────────────────────────────────────
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Découvrir'), actions: [
        IconButton(icon: const Icon(Icons.tune_outlined), onPressed: () {}),
      ]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un talent, un sport...',
                prefixIcon: const Icon(Icons.search, color: AppColors.grey400),
                filled: true,
                fillColor: AppColors.grey100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          // Filtres sport
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ['Tous', 'Football', 'Basketball', 'Athlétisme', 'Natation', 'Handball']
                .map((s) => Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(s),
                    selected: s == 'Tous',
                    onSelected: (_) {},
                    selectedColor: AppColors.primaryBg,
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(color: s == 'Tous' ? AppColors.primary : AppColors.grey600, fontSize: 13),
                  ),
                )).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Top Talents
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              const Text('Top Talents CI', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text('Voir tout')),
            ]),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.78,
              ),
              itemCount: 10,
              itemBuilder: (_, i) => _TalentCard(rank: i+1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TalentCard extends StatelessWidget {
  final int rank;
  const _TalentCard({required this.rank});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.primaryBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: const Center(child: Text('👤', style: TextStyle(fontSize: 48))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Talent Sportif', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                const Text('Football · Abidjan', style: TextStyle(color: AppColors.grey500, fontSize: 11)),
                const SizedBox(height: 6),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(6)),
                    child: Text('${85 + rank} ⭐', style: const TextStyle(color: AppColors.accentDark, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  Text('#$rank', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PLACEHOLDER SCREENS
// ─────────────────────────────────────────────────────────────
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: const Center(child: Text('Notifications — Bientôt disponible', style: TextStyle(color: AppColors.grey500))),
  );
}

class ProfileScreen extends StatelessWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mon Profil'), actions: [
      IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => context.push(Routes.editProfile)),
    ]),
    body: const Center(child: Text('Profil — En cours de développement', style: TextStyle(color: AppColors.grey500))),
  );
}

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Modifier le profil')),
    body: const Center(child: Text('Édition profil — Bientôt', style: TextStyle(color: AppColors.grey500))),
  );
}

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Messages')),
    body: const Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outlined, size: 48, color: AppColors.grey300),
        SizedBox(height: 12),
        Text('Messagerie Premium', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        SizedBox(height: 6),
        Text('Passe en Premium pour envoyer\net recevoir des messages.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.grey500, fontSize: 14)),
      ],
    )),
  );
}

class ChatScreen extends StatelessWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Conversation')),
    body: const Center(child: Text('Chat — En cours', style: TextStyle(color: AppColors.grey500))),
  );
}

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recherche')),
    body: const Center(child: Text('Recherche avancée — Bientôt', style: TextStyle(color: AppColors.grey500))),
  );
}
