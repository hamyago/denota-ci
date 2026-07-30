// lib/presentation/screens/admin/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import '../../../main.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/common/logout_action.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, int> _stats = {};
  List<Map<String, dynamic>> _pendingPosts = [];
  List<Map<String, dynamic>> _recentUsers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Stats globales
      final usersCount = await supabase.from('profiles').select('id').count();
      final postsCount = await supabase.from('posts').select('id').count();
      final pendingCount = await supabase.from('posts').select('id').eq('status', 'pending_moderation').count();
      final activeCount = await supabase.from('profiles').select('id').eq('status', 'active').count();

      _stats = {
        'users': usersCount.count,
        'posts': postsCount.count,
        'pending': pendingCount.count,
        'active': activeCount.count,
      };

      // Posts en attente de modération
      final pending = await supabase
          .from('posts')
          .select('id, title, content_type, status, created_at, author_id')
          .eq('status', 'pending_moderation')
          .order('created_at', ascending: false)
          .limit(20);
      _pendingPosts = List<Map<String, dynamic>>.from(pending as List);

      // Derniers inscrits
      final users = await supabase
          .from('profiles')
          .select('id, full_name, email, role, status, created_at')
          .order('created_at', ascending: false)
          .limit(20);
      _recentUsers = List<Map<String, dynamic>>.from(users as List);

      setState(() { _loading = false; });
    } catch (e) {
      setState(() {
        _error = e.toString().length > 120 ? e.toString().substring(0, 120) : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _moderatePost(String postId, String newStatus) async {
    try {
      final update = <String, dynamic>{'status': newStatus};
      // Sans published_at, le post n'apparaît pas dans le feed (tri par published_at).
      if (newStatus == 'published') {
        update['published_at'] = DateTime.now().toIso8601String();
      }
      await supabase.from('posts').update(update).eq('id', postId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newStatus == 'published' ? 'Post publié ✓' : 'Post rejeté')),
      );
      _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleUserStatus(String userId, String currentStatus) async {
    final newStatus = currentStatus == 'active' ? 'suspended' : 'active';
    try {
      await supabase.from('profiles').update({'status': newStatus}).eq('id', userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newStatus == 'active' ? 'Utilisateur activé ✓' : 'Utilisateur suspendu')),
      );
      _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Administration'),
          actions: const [LogoutMenuButton()],
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.grey400,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'Vue globale'),
              Tab(icon: Icon(Icons.pending_actions), text: 'Modération'),
              Tab(icon: Icon(Icons.people_outline), text: 'Utilisateurs'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Erreur : $_error', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _loadAll, child: const Text('Réessayer')),
                    ],
                  ))
                : TabBarView(
                    children: [
                      _OverviewTab(stats: _stats),
                      _ModerationTab(posts: _pendingPosts, onModerate: _moderatePost),
                      _UsersTab(users: _recentUsers, onToggleStatus: _toggleUserStatus),
                    ],
                  ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// TAB 1 : Vue globale avec statistiques
// ══════════════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final Map<String, int> stats;
  const _OverviewTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          _buildStatsGrid(),
          const SizedBox(height: 24),
          const Text('Résumé', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 12),
          _infoCard(Icons.person_add, 'Utilisateurs inscrits', '${stats['users'] ?? 0}', AppColors.primary),
          _infoCard(Icons.check_circle, 'Comptes actifs', '${stats['active'] ?? 0}', Colors.green),
          _infoCard(Icons.video_library, 'Publications totales', '${stats['posts'] ?? 0}', AppColors.accent),
          _infoCard(Icons.pending, 'En attente de modération', '${stats['pending'] ?? 0}', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final items = [
      _StatItem('Utilisateurs', stats['users'] ?? 0, Icons.people, AppColors.primary),
      _StatItem('Actifs', stats['active'] ?? 0, Icons.verified_user, Colors.green),
      _StatItem('Posts', stats['posts'] ?? 0, Icons.article, AppColors.accent),
      _StatItem('En attente', stats['pending'] ?? 0, Icons.hourglass_top, Colors.orange),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: items.map((item) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(item.icon, color: item.color, size: 24),
            Text('${item.value}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: item.color)),
            Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.grey400)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _infoCard(IconData icon, String title, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), radius: 20, child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14, color: AppColors.ink))),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _StatItem {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _StatItem(this.label, this.value, this.icon, this.color);
}

// ══════════════════════════════════════════════════════════
// TAB 2 : Modération des posts
// ══════════════════════════════════════════════════════════
class _ModerationTab extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final Future<void> Function(String postId, String newStatus) onModerate;
  const _ModerationTab({required this.posts, required this.onModerate});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 56, color: AppColors.primary),
            SizedBox(height: 16),
            Text('Aucun post en attente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('Tous les contenus ont été modérés', style: TextStyle(color: AppColors.grey400, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final post = posts[i];
        final type = post['content_type'] as String? ?? 'video';
        final title = post['title'] as String? ?? 'Sans titre';
        final createdAt = post['created_at'] as String? ?? '';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    type == 'video' ? Icons.videocam : type == 'article' ? Icons.article : Icons.short_text,
                    color: AppColors.primary, size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: const Text('En attente', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Type: $type  •  $createdAt', style: const TextStyle(fontSize: 11, color: AppColors.grey400)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => onModerate(post['id'] as String, 'rejected'),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Rejeter'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => onModerate(post['id'] as String, 'published'),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Publier'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════
// TAB 3 : Gestion des utilisateurs
// ══════════════════════════════════════════════════════════
class _UsersTab extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final Future<void> Function(String userId, String currentStatus) onToggleStatus;
  const _UsersTab({required this.users, required this.onToggleStatus});

  Color _roleColor(String role) {
    switch (role) {
      case 'athlete': return AppColors.primary;
      case 'recruiter': return AppColors.accent;
      case 'admin': return Colors.red;
      case 'institution': return Colors.blue;
      case 'expert': return Colors.purple;
      default: return AppColors.grey400;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'athlete': return 'Athlète';
      case 'recruiter': return 'Recruteur';
      case 'admin': return 'Admin';
      case 'institution': return 'Institution';
      case 'expert': return 'Expert';
      case 'sponsor': return 'Sponsor';
      default: return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Center(child: Text('Aucun utilisateur'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final user = users[i];
        final name = user['full_name'] as String? ?? 'Inconnu';
        final email = user['email'] as String? ?? '';
        final role = user['role'] as String? ?? 'athlete';
        final status = user['status'] as String? ?? 'pending';
        final isActive = status == 'active';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: _roleColor(role).withValues(alpha: 0.1),
                radius: 22,
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(fontWeight: FontWeight.w700, color: _roleColor(role)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(email, style: const TextStyle(fontSize: 11, color: AppColors.grey400)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: _roleColor(role).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text(_roleLabel(role), style: TextStyle(fontSize: 10, color: _roleColor(role), fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isActive ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(isActive ? 'Actif' : status,
                            style: TextStyle(fontSize: 10, color: isActive ? Colors.green : Colors.orange, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(isActive ? Icons.block : Icons.check_circle, color: isActive ? Colors.red : Colors.green, size: 20),
                tooltip: isActive ? 'Suspendre' : 'Activer',
                onPressed: () => onToggleStatus(user['id'] as String, status),
              ),
            ],
          ),
        );
      },
    );
  }
}
