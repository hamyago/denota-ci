// lib/presentation/screens/recruiter/recruiter_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_colors.dart';
import '../profile/profile_screen.dart';
import '../search/discover_screen.dart';
import '../../widgets/common/logout_action.dart';
import '../../../data/repositories/recruiter_repository.dart';
import '../../../data/services/scouting_pdf_service.dart';
import '../../../main.dart';

class RecruiterDashboardScreen extends StatefulWidget {
  const RecruiterDashboardScreen({super.key});

  @override
  State<RecruiterDashboardScreen> createState() => _RecruiterDashboardScreenState();
}

class _RecruiterDashboardScreenState extends State<RecruiterDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _repo = RecruiterRepository();
  late TabController _tabs;

  RecruiterStatsModel? _stats;
  List<Map<String, dynamic>> _topTalents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _repo.getStats(),
        _repo.getTopTalents(limit: 8),
      ]);
      if (!mounted) return;
      setState(() {
        _stats      = results[0] as RecruiterStatsModel;
        _topTalents = results[1] as List<Map<String, dynamic>>;
        _loading    = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700),
            children: [
              TextSpan(text: 'De', style: TextStyle(color: AppColors.ink)),
              TextSpan(text: 'No', style: TextStyle(color: AppColors.primary)),
              TextSpan(text: 'Ta', style: TextStyle(color: AppColors.accent)),
              TextSpan(text: ' Pro', style: TextStyle(color: AppColors.grey400, fontSize: 14)),
            ],
          ),
        ),
        actions: [
          if ((_stats?.unreadAlerts ?? 0) > 0)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => _tabs.animateTo(2),
                ),
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        '${_stats!.unreadAlerts}',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => _tabs.animateTo(2)),
          IconButton(icon: const Icon(Icons.search), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiscoverScreen()))),
          const LogoutMenuButton(),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.grey400,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Tableau de bord'),
            Tab(text: 'Favoris'),
            Tab(text: 'Alertes'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabs,
              children: [
                _OverviewTab(stats: _stats!, topTalents: _topTalents, repo: _repo),
                _FavoritesTab(repo: _repo),
                _AlertsTab(repo: _repo),
              ],
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TAB 1 — TABLEAU DE BORD
// ══════════════════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final RecruiterStatsModel stats;
  final List<Map<String, dynamic>> topTalents;
  final RecruiterRepository repo;

  const _OverviewTab({required this.stats, required this.topTalents, required this.repo});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {},
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Bonjour ───────────────────────────────
            Text(
              'Bonjour 👋',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
            const Text('Voici un aperçu de votre activité.', style: TextStyle(fontSize: 14, color: AppColors.grey400)),
            const SizedBox(height: 20),

            // ── Stats cards ───────────────────────────
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _StatCard(value: '${stats.favoritesCount}', label: 'Talents sauvegardés', icon: Icons.bookmark_outline, color: AppColors.primary),
                _StatCard(value: '${stats.contactsSent}',   label: 'Contacts envoyés',   icon: Icons.send_outlined,     color: AppColors.blue),
                _StatCard(value: '${stats.unreadAlerts}',   label: 'Alertes non lues',   icon: Icons.notifications_outlined, color: stats.unreadAlerts > 0 ? AppColors.error : AppColors.grey400),
                _StatCard(value: '${stats.recruitmentsCount}', label: 'Recrutements',     icon: Icons.handshake_outlined, color: AppColors.accent),
              ],
            ),
            const SizedBox(height: 24),

            // ── Actions rapides ───────────────────────
            const Text('Actions rapides', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _QuickAction(
                  icon: Icons.search,
                  label: 'Chercher\nun talent',
                  color: AppColors.primary,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiscoverScreen())),
                )),
                const SizedBox(width: 10),
                Expanded(child: _QuickAction(
                  icon: Icons.map_outlined,
                  label: 'Carte des\ntalents',
                  color: AppColors.blue,
                  onTap: () {},
                )),
                const SizedBox(width: 10),
                Expanded(child: _QuickAction(
                  icon: Icons.tune_outlined,
                  label: 'Filtres\navancés',
                  color: AppColors.accent,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiscoverScreen())),
                )),
                const SizedBox(width: 10),
                Expanded(child: _QuickAction(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'Mes\nrapports',
                  color: AppColors.error,
                  onTap: () {},
                )),
              ],
            ),
            const SizedBox(height: 24),

            // ── Top talents ───────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Top Talents CI', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
                TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiscoverScreen())), child: const Text('Voir tout →')),
              ],
            ),
            const SizedBox(height: 10),
            ...topTalents.take(5).map((t) => _TalentListTile(
              talent: t,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileScreen(userId: t['id'] as String))),
              onFavorite: () => repo.addFavorite(t['id'] as String),
              onPdf: () async {
                _showPdfLoading(context);
                final svc = ScoutingPdfService();
                try {
                  final file = await svc.generateScoutingReport(
                    athleteId:     t['id'] as String,
                    recruiterName: supabase.auth.currentUser?.email ?? '',
                    recruiterOrg:  'DeNoTa Pro',
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    await svc.shareReport(file, t['full_name'] as String? ?? '');
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur PDF : $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showPdfLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(width: 16),
            Text('Génération du rapport PDF...'),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TAB 2 — FAVORIS
// ══════════════════════════════════════════════════════════════
class _FavoritesTab extends StatefulWidget {
  final RecruiterRepository repo;
  const _FavoritesTab({required this.repo});

  @override
  State<_FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<_FavoritesTab> {
  List<FavoriteModel> _favorites = [];
  List<String> _lists = ['all'];
  String _currentList = 'all';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      widget.repo.getFavorites(listName: _currentList),
      widget.repo.getFavoriteLists(),
    ]);
    if (!mounted) return;
    setState(() {
      _favorites = results[0] as List<FavoriteModel>;
      _lists     = results[1] as List<String>;
      _loading   = false;
    });
  }

  Future<void> _removeFavorite(FavoriteModel fav) async {
    await widget.repo.removeFavorite(fav.athleteId);
    setState(() => _favorites.remove(fav));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${fav.athleteName} retiré des favoris'),
          action: SnackBarAction(label: 'Annuler', onPressed: () async {
            await widget.repo.addFavorite(fav.athleteId);
            _load();
          }),
        ),
      );
    }
  }

  void _showAddNoteDialog(FavoriteModel fav) {
    final ctrl = TextEditingController(text: fav.note);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Note — ${fav.athleteName}'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Vos observations sur ce talent...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogCtx);
              await widget.repo.updateFavoriteNote(fav.id, ctrl.text.trim());
              navigator.pop();
              _load();
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));

    return Column(
      children: [
        // Filtres listes
        if (_lists.length > 1)
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: _lists.length,
              itemBuilder: (_, i) {
                final l = _lists[i];
                final selected = l == _currentList;
                final label = l == 'all' ? 'Tous' : l;
                return GestureDetector(
                  onTap: () { setState(() => _currentList = l); _load(); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.grey100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(label, style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500,
                      color: selected ? Colors.white : AppColors.grey500,
                    )),
                  ),
                );
              },
            ),
          ),

        // Liste favoris
        Expanded(
          child: _favorites.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_outline, size: 52, color: AppColors.grey300),
                      SizedBox(height: 12),
                      Text('Aucun favori', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.grey500)),
                      SizedBox(height: 6),
                      Text('Sauvegardez vos talents prometteurs\ndans l\'onglet Découvrir.',
                          textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.grey400)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _favorites.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final fav = _favorites[i];
                      return _FavoriteCard(
                        favorite: fav,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileScreen(userId: fav.athleteId))),
                        onRemove: () => _removeFavorite(fav),
                        onNote: () => _showAddNoteDialog(fav),
                        onPdf: () async {
                          final svc = ScoutingPdfService();
                          final file = await svc.generateScoutingReport(
                            athleteId:     fav.athleteId,
                            recruiterName: supabase.auth.currentUser?.email ?? '',
                            recruiterOrg:  'DeNoTa Pro',
                          );
                          await svc.shareReport(file, fav.athleteName ?? '');
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TAB 3 — ALERTES
// ══════════════════════════════════════════════════════════════
class _AlertsTab extends StatefulWidget {
  final RecruiterRepository repo;
  const _AlertsTab({required this.repo});

  @override
  State<_AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<_AlertsTab> {
  List<AlertModel> _alerts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final alerts = await widget.repo.getAlerts();
    if (!mounted) return;
    setState(() { _alerts = alerts; _loading = false; });
  }

  Future<void> _markAllRead() async {
    await widget.repo.markAllAlertsRead();
    // isRead est final — on recharge simplement les données
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));

    final unread = _alerts.where((a) => !a.isRead).length;

    return Column(
      children: [
        if (unread > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Text('$unread alerte${unread > 1 ? 's' : ''} non lue${unread > 1 ? 's' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
                const Spacer(),
                TextButton(onPressed: _markAllRead, child: const Text('Tout marquer lu')),
              ],
            ),
          ),
        Expanded(
          child: _alerts.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none_outlined, size: 52, color: AppColors.grey300),
                      SizedBox(height: 12),
                      Text('Aucune alerte', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.grey500)),
                      SizedBox(height: 6),
                      Text('Les nouvelles activités apparaîtront ici.', style: TextStyle(fontSize: 13, color: AppColors.grey400)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _alerts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.grey200),
                    itemBuilder: (_, i) {
                      final a = _alerts[i];
                      return _AlertTile(
                        alert: a,
                        onTap: () async {
                          if (!a.isRead) {
                            await widget.repo.markAlertRead(a.id);
                            _load();
                          }
                          if (context.mounted && a.athleteId.isNotEmpty) {
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileScreen(userId: a.athleteId)));
                          }
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// WIDGETS COMMUNS
// ══════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;

  const _StatCard({required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.grey400, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color, height: 1.3)),
          ],
        ),
      ),
    );
  }
}

class _TalentListTile extends StatelessWidget {
  final Map<String, dynamic> talent;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onPdf;

  const _TalentListTile({
    required this.talent,
    required this.onTap,
    required this.onFavorite,
    required this.onPdf,
  });

  @override
  Widget build(BuildContext context) {
    final name     = talent['full_name'] as String? ?? '';
    final avatar   = talent['avatar_url'] as String?;
    final city     = talent['city'] as String?;
    final sport    = talent['sport_name'] as String?;
    final position = talent['position_name'] as String?;
    final score    = (talent['talent_score'] as num?)?.toDouble() ?? 0;
    final level    = talent['level'] as String?;
    final kyc      = talent['kyc_level'] as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primaryBg,
              backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
              child: avatar == null
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))
                  : null,
            ),
            const SizedBox(width: 12),
            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.ink)),
                    if (kyc != null && kyc != 'none' && kyc != 'email') ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, color: AppColors.primary, size: 14),
                    ],
                  ]),
                  Text(
                    [if (sport != null) sport, if (position != null) position, if (city != null) city]
                        .join(' · '),
                    style: const TextStyle(fontSize: 12, color: AppColors.grey500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (level != null)
                    Text(
                      level == 'professional' ? '🏆 Pro' : level == 'semi_pro' ? '⭐ Semi-Pro' : '🌱 Amateur',
                      style: const TextStyle(fontSize: 11, color: AppColors.grey400),
                    ),
                ],
              ),
            ),
            // Score
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(score.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.accentDark)),
                ),
                const Text('Score', style: TextStyle(fontSize: 9, color: AppColors.grey400)),
              ],
            ),
            const SizedBox(width: 8),
            // Actions
            Column(
              children: [
                _IconBtn(icon: Icons.bookmark_border, color: AppColors.primary, onTap: onFavorite),
                const SizedBox(height: 4),
                _IconBtn(icon: Icons.picture_as_pdf_outlined, color: AppColors.error, onTap: onPdf),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final FavoriteModel favorite;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onNote;
  final VoidCallback onPdf;

  const _FavoriteCard({
    required this.favorite,
    required this.onTap,
    required this.onRemove,
    required this.onNote,
    required this.onPdf,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primaryBg,
                  backgroundImage: favorite.athleteAvatarUrl != null
                      ? CachedNetworkImageProvider(favorite.athleteAvatarUrl!)
                      : null,
                  child: favorite.athleteAvatarUrl == null
                      ? Text(
                          (favorite.athleteName ?? '?')[0].toUpperCase(),
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(favorite.athleteName ?? 'Inconnu',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.ink)),
                      Text(
                        [
                          if (favorite.sportName != null) favorite.sportName,
                          if (favorite.athleteCity != null) favorite.athleteCity,
                        ].join(' · '),
                        style: const TextStyle(fontSize: 12, color: AppColors.grey500),
                      ),
                      if (favorite.levelLabel.isNotEmpty)
                        Text(favorite.levelLabel,
                            style: const TextStyle(fontSize: 11, color: AppColors.grey400)),
                    ],
                  ),
                ),
                Column(
                  children: [
                    if (favorite.talentScore != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(8)),
                        child: Text('${favorite.talentScore!.toStringAsFixed(0)} ⭐',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accentDark)),
                      ),
                    const SizedBox(height: 4),
                    Text(favorite.listName == 'default' ? '📁 Défaut' : '📁 ${favorite.listName}',
                        style: const TextStyle(fontSize: 10, color: AppColors.grey400)),
                  ],
                ),
              ],
            ),

            // Note recruteur
            if (favorite.note != null && favorite.note!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sticky_note_2_outlined, size: 14, color: AppColors.accentDark),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(favorite.note!,
                          style: const TextStyle(fontSize: 12, color: AppColors.accentDark, height: 1.4)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Actions
            Row(
              children: [
                _ActionChip(icon: Icons.message_outlined,           label: 'Contacter', color: AppColors.primary, onTap: () {}),
                const SizedBox(width: 8),
                _ActionChip(icon: Icons.sticky_note_2_outlined,    label: 'Note',      color: AppColors.accent,   onTap: onNote),
                const SizedBox(width: 8),
                _ActionChip(icon: Icons.picture_as_pdf_outlined,   label: 'PDF',       color: AppColors.error,    onTap: onPdf),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.grey400, size: 20),
                  onPressed: onRemove,
                  tooltip: 'Supprimer des favoris',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback onTap;

  const _AlertTile({required this.alert, required this.onTap});

  IconData get _icon {
    switch (alert.alertType) {
      case 'contact_request': return Icons.mail_outline;
      case 'profile_view':    return Icons.visibility_outlined;
      case 'recruitment':     return Icons.handshake_outlined;
      default:                return Icons.notifications_outlined;
    }
  }

  Color get _iconColor {
    switch (alert.alertType) {
      case 'contact_request': return AppColors.primary;
      case 'profile_view':    return AppColors.blue;
      case 'recruitment':     return AppColors.accent;
      default:                return AppColors.grey400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: alert.isRead ? Colors.transparent : AppColors.primaryBg.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: _iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.title,
                      style: TextStyle(
                        fontWeight: alert.isRead ? FontWeight.w400 : FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.ink,
                      )),
                  if (alert.body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(alert.body, style: const TextStyle(fontSize: 12, color: AppColors.grey500), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 4),
                  Text(timeago.format(alert.createdAt, locale: 'fr'),
                      style: const TextStyle(fontSize: 11, color: AppColors.grey300)),
                ],
              ),
            ),
            if (!alert.isRead)
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
          ],
        ),
      ),
    );
  }
}

// ── Micro-widgets ─────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
