// lib/presentation/screens/home/feed_screen.dart
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../main.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/video/video_player_widget.dart';
import '../post/create_post_screen.dart';

/// Fil d'actualité : vidéos publiées par les athlètes.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  static const int _pageSize = 10;

  final List<Map<String, dynamic>> _posts = [];
  final Set<String> _likedIds = {};
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >
              _scrollCtrl.position.maxScrollExtent - 400 &&
          !_loadingMore &&
          _hasMore) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _loading = true;
        _error = null;
        _hasMore = true;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final from = refresh ? 0 : _posts.length;
      final rows = await supabase
          .from('posts')
          .select('''
            *,
            profiles!author_id(
              full_name, avatar_url,
              athlete_profiles(
                talent_score,
                sports:primary_sport_id(name_fr)
              )
            )
          ''')
          .eq('status', 'published')
          .order('published_at', ascending: false)
          .range(from, from + _pageSize - 1);

      final list = List<Map<String, dynamic>>.from(rows as List);

      // Likes de l'utilisateur courant sur cette page
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

      setState(() {
        if (refresh) _posts.clear();
        _posts.addAll(list);
        _hasMore = list.length == _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur : ${e.toString().length > 150 ? e.toString().substring(0, 150) : e.toString()}';
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final id = post['id'] as String;
    final liked = _likedIds.contains(id);

    // Optimiste
    setState(() {
      if (liked) {
        _likedIds.remove(id);
        post['likes_count'] = (post['likes_count'] as int? ?? 1) - 1;
      } else {
        _likedIds.add(id);
        post['likes_count'] = (post['likes_count'] as int? ?? 0) + 1;
      }
    });

    try {
      if (liked) {
        await supabase
            .from('post_likes')
            .delete()
            .eq('post_id', id)
            .eq('profile_id', uid);
      } else {
        await supabase
            .from('post_likes')
            .insert({'post_id': id, 'profile_id': uid});
      }
    } catch (_) {
      // rollback silencieux
      setState(() {
        if (liked) {
          _likedIds.add(id);
          post['likes_count'] = (post['likes_count'] as int? ?? 0) + 1;
        } else {
          _likedIds.remove(id);
          post['likes_count'] = (post['likes_count'] as int? ?? 1) - 1;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            children: [
              TextSpan(text: 'De', style: TextStyle(color: AppColors.ink)),
              TextSpan(text: 'No', style: TextStyle(color: AppColors.accent)),
              TextSpan(text: 'Ta', style: TextStyle(color: AppColors.ink)),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Publier',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreatePostScreen()),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _posts.isEmpty) {
      return _ErrorState(message: _error!, onRetry: () => _load(refresh: true));
    }
    if (_posts.isEmpty) {
      return _EmptyFeed(onRefresh: () => _load(refresh: true));
    }

    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(16),
        itemCount: _posts.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final post = _posts[i];
          final profile = post['profiles'] as Map<String, dynamic>?;
          // athlete_profiles est une relation → renvoyée sous forme de liste
          final athleteList = profile?['athlete_profiles'] as List<dynamic>?;
          final athlete = (athleteList != null && athleteList.isNotEmpty)
              ? athleteList.first as Map<String, dynamic>?
              : null;
          final sport =
              (athlete?['sports'] as Map<String, dynamic>?)?['name_fr']
                      as String? ??
                  'Athlète';
          final mediaUrls = (post['media_urls'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              [];
          final publishedAt = DateTime.tryParse(
              (post['published_at'] ?? post['created_at']) as String? ?? '');

          return FeedVideoCard(
            authorName: profile?['full_name'] as String? ?? 'Athlète',
            authorAvatarUrl: profile?['avatar_url'] as String?,
            authorSport: sport,
            talentScore:
                (athlete?['talent_score'] as num?)?.toDouble() ?? 0,
            videoUrl: mediaUrls.isNotEmpty ? mediaUrls.first : '',
            thumbnailUrl: post['thumbnail_url'] as String?,
            title: post['title'] as String?,
            body: post['body'] as String?,
            likesCount: post['likes_count'] as int? ?? 0,
            commentsCount: post['comments_count'] as int? ?? 0,
            viewsCount: post['views_count'] as int? ?? 0,
            timeAgo: publishedAt != null
                ? timeago.format(publishedAt, locale: 'fr')
                : '',
            isLiked: _likedIds.contains(post['id'] as String),
            onLike: () => _toggleLike(post),
          );
        },
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _EmptyFeed({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.sports_soccer, size: 64, color: AppColors.grey400),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Aucune vidéo pour le moment',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Soyez le premier à publier votre talent !',
              style: TextStyle(fontSize: 13, color: AppColors.grey400),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: AppColors.grey400),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
