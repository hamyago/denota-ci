// lib/presentation/screens/home/tiktok_feed_screen.dart
//
// Fil d'actualité vertical plein écran, style TikTok :
// - défilement vertical (PageView), une publication par écran
// - lecture auto de la vidéo active, pause des autres
// - overlay : auteur + légende en bas, actions à droite
//   (like, commentaires, partage, SIGNALER)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../main.dart';
import '../../../core/theme/app_colors.dart';

class TikTokFeedScreen extends StatefulWidget {
  const TikTokFeedScreen({super.key});

  @override
  State<TikTokFeedScreen> createState() => _TikTokFeedScreenState();
}

class _TikTokFeedScreenState extends State<TikTokFeedScreen> {
  final PageController _pageCtrl = PageController();
  final List<Map<String, dynamic>> _posts = [];
  final List<Map<String, dynamic>> _sports = [];
  final Set<String> _likedIds = {};
  int? _sportFilter; // null = Tous
  bool _loading = true;
  String? _error;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _loadSports();
    _load();
  }

  Future<void> _loadSports() async {
    try {
      final data = await supabase
          .from('sports')
          .select('id, name_fr')
          .order('name_fr');
      if (!mounted) return;
      setState(() {
        _sports
          ..clear()
          ..addAll(List<Map<String, dynamic>>.from(data as List));
      });
    } catch (_) {
      // pas de filtre si la liste échoue : on garde "Tous"
    }
  }

  void _selectSport(int? sportId) {
    if (_sportFilter == sportId) return;
    setState(() { _sportFilter = sportId; _current = 0; });
    if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(0);
    _load();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      var query = supabase
          .from('posts')
          .select('''
            *,
            profiles!author_id(
              full_name, avatar_url,
              athlete_profiles!athlete_profiles_profile_id_fkey(
                talent_score,
                sports:primary_sport_id(name_fr)
              )
            )
          ''')
          .eq('status', 'published');

      if (_sportFilter != null) {
        query = query.eq('sport_id', _sportFilter!);
      }

      final rows = await query
          .order('published_at', ascending: false)
          .limit(30);

      final list = List<Map<String, dynamic>>.from(rows as List);

      final uid = supabase.auth.currentUser?.id;
      if (uid != null && list.isNotEmpty) {
        final ids = list.map((e) => e['id'] as String).toList();
        final likes = await supabase
            .from('post_likes')
            .select('post_id')
            .eq('profile_id', uid)
            .inFilter('post_id', ids);
        for (final l in List<Map<String, dynamic>>.from(likes as List)) {
          _likedIds.add(l['post_id'] as String);
        }
      }

      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(list);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final id = post['id'] as String;
    final liked = _likedIds.contains(id);
    setState(() {
      if (liked) {
        _likedIds.remove(id);
        final cur = post['likes_count'] as int? ?? 1;
        post['likes_count'] = cur > 0 ? cur - 1 : 0;
      } else {
        _likedIds.add(id);
        post['likes_count'] = (post['likes_count'] as int? ?? 0) + 1;
      }
    });
    try {
      if (liked) {
        await supabase.from('post_likes').delete().eq('post_id', id).eq('profile_id', uid);
      } else {
        await supabase.from('post_likes').insert({'post_id': id, 'profile_id': uid});
      }
    } catch (_) {
      // en cas d'échec réseau, on ne bloque pas l'UI
    }
  }

  // ── SIGNALEMENT ─────────────────────────────────────────────
  Future<void> _report(Map<String, dynamic> post) async {
    final reasons = <String>[
      'Contenu inapproprié',
      'Violence ou contenu choquant',
      'Harcèlement',
      'Nudité ou contenu sexuel',
      'Fausse information',
      'Spam',
      'Autre',
    ];

    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Signaler cette publication',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: reasons.map((r) => ListTile(
                      leading: const Icon(Icons.flag_outlined, color: AppColors.error),
                      title: Text(r),
                      onTap: () => Navigator.pop(context, r),
                    )).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (reason == null) return;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      await supabase.from('post_reports').insert({
        'post_id': post['id'],
        'reporter_id': uid,
        'reason': reason,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Merci. La publication a été signalée à la modération.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on PostgrestException catch (e) {
      if (!mounted) return;
      // 23505 = déjà signalé par cet utilisateur (contrainte unique)
      final already = e.code == '23505';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(already
              ? 'Vous avez déjà signalé cette publication.'
              : 'Erreur : ${e.message}'),
          backgroundColor: already ? AppColors.warning : AppColors.error,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildBody(),
          // Menu déroulant compact de sport (overlay haut, couleurs DeNoTa)
          Positioned(
            top: 0, left: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, top: 6),
                child: _sportDropdownButton(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _currentSportLabel {
    if (_sportFilter == null) return 'Tous les sports';
    final s = _sports.firstWhere(
      (e) => e['id'] == _sportFilter,
      orElse: () => const {},
    );
    return (s['name_fr'] as String?) ?? 'Sport';
  }

  Widget _sportDropdownButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: _openSportSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_martial_arts, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                _currentSportLabel,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, color: AppColors.accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _openSportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Choisir un sport',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _sportSheetItem('Tous les sports', null),
                  ..._sports.map((s) => _sportSheetItem(
                        s['name_fr'] as String? ?? '',
                        s['id'] as int?,
                      )),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sportSheetItem(String label, int? sportId) {
    final selected = _sportFilter == sportId;
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? AppColors.primary : AppColors.grey400,
      ),
      title: Text(label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.ink,
          )),
      onTap: () {
        Navigator.pop(context);
        _selectSport(sportId);
      },
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              Text('Erreur de chargement :\n$_error',
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }
    if (_posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: const [
          SizedBox(height: 200),
          Center(child: Text('Aucune publication pour le moment',
              style: TextStyle(color: Colors.white70, fontSize: 16))),
        ]),
      );
    }

    return PageView.builder(
      controller: _pageCtrl,
      scrollDirection: Axis.vertical,
      itemCount: _posts.length,
      onPageChanged: (i) => setState(() => _current = i),
      itemBuilder: (context, i) {
        final post = _posts[i];
        return _TikTokItem(
          key: ValueKey(post['id']),
          post: post,
          isActive: i == _current,
          isLiked: _likedIds.contains(post['id'] as String),
          onLike: () => _toggleLike(post),
          onReport: () => _report(post),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Une publication plein écran
// ══════════════════════════════════════════════════════════════
class _TikTokItem extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isActive;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onReport;

  const _TikTokItem({
    super.key,
    required this.post,
    required this.isActive,
    required this.isLiked,
    required this.onLike,
    required this.onReport,
  });

  @override
  State<_TikTokItem> createState() => _TikTokItemState();
}

class _TikTokItemState extends State<_TikTokItem> {
  VideoPlayerController? _ctrl;
  bool _ready = false;
  bool _paused = false;

  bool get _isVideo => (widget.post['content_type'] as String? ?? '') == 'video';

  String? get _mediaUrl {
    final raw = widget.post['media_urls'];
    if (raw is List && raw.isNotEmpty) return raw.first.toString();
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (_isVideo && _mediaUrl != null) _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(_mediaUrl!));
      await c.initialize();
      if (!mounted) { c.dispose(); return; }
      c.setLooping(true);
      setState(() { _ctrl = c; _ready = true; });
      if (widget.isActive) c.play();
    } catch (_) {
      // vidéo illisible : on laisse l'affichage image/placeholder
    }
  }

  @override
  void didUpdateWidget(covariant _TikTokItem old) {
    super.didUpdateWidget(old);
    if (_ctrl != null && _ready) {
      if (widget.isActive && !_paused) {
        _ctrl!.play();
      } else {
        _ctrl!.pause();
      }
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _ctrl;
    if (c == null || !_ready) return;
    setState(() {
      _paused = !_paused;
      _paused ? c.pause() : c.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final profile = post['profiles'] as Map<String, dynamic>?;
    final author = profile?['full_name'] as String? ?? 'Athlète';
    final title = post['title'] as String?;
    final body = post['body'] as String?;
    final likes = post['likes_count'] as int? ?? 0;
    final comments = post['comments_count'] as int? ?? 0;

    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Média ────────────────────────────────────
          _buildMedia(),

          // ── Dégradé bas pour lisibilité ──────────────
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black54],
              ),
            ),
          ),

          // ── Indicateur pause ─────────────────────────
          if (_isVideo && _paused)
            const Center(
              child: Icon(Icons.play_arrow, color: Colors.white70, size: 72),
            ),

          // ── Infos auteur + légende (bas gauche) ──────
          Positioned(
            left: 14, right: 84, bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('@$author',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                if (title != null && title.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(title,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                if (body != null && body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(body,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),

          // ── Colonne d'actions (droite) ───────────────
          Positioned(
            right: 10, bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _action(
                  icon: widget.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: widget.isLiked ? AppColors.error : Colors.white,
                  label: '$likes',
                  onTap: widget.onLike,
                ),
                const SizedBox(height: 18),
                _action(icon: Icons.mode_comment_outlined, color: Colors.white, label: '$comments', onTap: () {}),
                const SizedBox(height: 18),
                _action(icon: Icons.share_outlined, color: Colors.white, label: 'Partager', onTap: _share),
                const SizedBox(height: 18),
                _action(icon: Icons.flag_outlined, color: Colors.white, label: 'Signaler', onTap: widget.onReport),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _share() {
    final url = _mediaUrl;
    if (url == null) return;
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lien copié dans le presse-papiers')),
    );
  }

  Widget _buildMedia() {
    if (_isVideo) {
      if (_ready && _ctrl != null) {
        return FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: _ctrl!.value.size.width,
            height: _ctrl!.value.size.height,
            child: VideoPlayer(_ctrl!),
          ),
        );
      }
      // Chargement vidéo
      final thumb = widget.post['thumbnail_url'] as String?;
      return Stack(
        fit: StackFit.expand,
        children: [
          if (thumb != null)
            CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover)
          else
            Container(color: Colors.black),
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      );
    }

    // Image / status
    final url = _mediaUrl;
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: Colors.black,
            child: const Center(child: CircularProgressIndicator(color: Colors.white))),
        errorWidget: (_, __, ___) => Container(color: Colors.black,
            child: const Center(child: Icon(Icons.broken_image, color: Colors.white38, size: 48))),
      );
    }

    // Texte pur
    return Container(color: AppColors.ink);
  }

  Widget _action({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
