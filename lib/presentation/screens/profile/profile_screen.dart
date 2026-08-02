// lib/presentation/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_colors.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../main.dart';
import '../../widgets/profile/talent_score_badge.dart';
import '../../widgets/video/video_player_widget.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _repo = ProfileRepository();
  late TabController _tabs;

  ProfileModel? _profile;
  AthleteProfileModel? _athleteProfile;
  List<PostModel> _posts = [];
  List<AthleteStatsModel> _stats = [];
  List<ExpertRatingModel> _ratings = [];
  List<AchievementModel> _achievements = [];
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isFollowing = false;
  bool _loading = true;
  bool _isOwn = false;

  String get _userId =>
      widget.userId ?? supabase.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _isOwn = widget.userId == null ||
        widget.userId == supabase.auth.currentUser?.id;
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        _repo.getProfile(_userId),
        _repo.getAthleteProfile(_userId),
        _repo.getProfilePosts(_userId),
        _repo.getAthleteStats(_userId),
        _repo.getExpertRatings(_userId),
        _repo.getAchievements(_userId),
        _repo.getFollowersCount(_userId),
        _repo.getFollowingCount(_userId),
        if (!_isOwn) _repo.isFollowing(_userId),
      ]);

      if (!mounted) return;
      setState(() {
        _profile         = results[0] as ProfileModel?;
        _athleteProfile  = results[1] as AthleteProfileModel?;
        _posts           = results[2] as List<PostModel>;
        _stats           = results[3] as List<AthleteStatsModel>;
        _ratings         = results[4] as List<ExpertRatingModel>;
        _achievements    = results[5] as List<AchievementModel>;
        _followersCount  = results[6] as int;
        _followingCount  = results[7] as int;
        if (!_isOwn && results.length > 8) _isFollowing = results[8] as bool;
        _loading = false;
      });

      if (!_isOwn) _repo.incrementProfileViews(_userId);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    // Recharge le profil au retour (photo, bio, etc. peuvent avoir changé)
    if (mounted) {
      setState(() => _loading = true);
      await _loadAll();
    }
  }

  Future<void> _toggleFollow() async {
    setState(() => _isFollowing = !_isFollowing);
    if (_isFollowing) { _followersCount++; } else { _followersCount--; }
    try {
      await _repo.toggleFollow(_userId);
    } catch (_) {
      setState(() {
        _isFollowing = !_isFollowing;
        if (_isFollowing) { _followersCount++; } else { _followersCount--; }
      });
    }
  }

  void _showSettingsMenu(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Modifier le profil'),
              onTap: () {
                Navigator.of(ctx).pop();
                _openEditProfile();
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Se déconnecter', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.of(ctx).pop();
                final confirm = await showDialog<bool>(
                  context: ctx,
                  builder: (c) => AlertDialog(
                    title: const Text('Déconnexion'),
                    content: const Text('Es-tu sûr de vouloir te déconnecter ?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Annuler')),
                      TextButton(
                        onPressed: () => Navigator.of(c).pop(true),
                        child: const Text('Déconnecter', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await supabase.auth.signOut();
                  if (ctx.mounted) {
                    Navigator.of(ctx).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_profile == null) {
      return const Scaffold(body: Center(child: Text('Profil introuvable')));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          _ProfileSliverAppBar(
            profile: _profile!,
            athleteProfile: _athleteProfile,
            followersCount: _followersCount,
            followingCount: _followingCount,
            postsCount: _posts.length,
            isOwn: _isOwn,
            isFollowing: _isFollowing,
            onFollow: _toggleFollow,
            onEdit: _openEditProfile,
            onSettings: () => _showSettingsMenu(context),
          ),
        ],
        body: Column(
          children: [
            // ── Tabs ──────────────────────────────────────
            Container(
              color: AppColors.white,
              child: TabBar(
                controller: _tabs,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.grey400,
                indicatorColor: AppColors.primary,
                indicatorWeight: 2.5,
                labelStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: 'Publications'),
                  Tab(text: 'Stats'),
                  Tab(text: 'Évaluations'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _PostsTab(posts: _posts, achievements: _achievements),
                  _StatsTab(stats: _stats, athleteProfile: _athleteProfile),
                  _RatingsTab(ratings: _ratings),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sliver AppBar (Header du profil) ─────────────────────
class _ProfileSliverAppBar extends StatelessWidget {
  final ProfileModel profile;
  final AthleteProfileModel? athleteProfile;
  final int followersCount, followingCount, postsCount;
  final bool isOwn, isFollowing;
  final VoidCallback onFollow, onEdit, onSettings;

  const _ProfileSliverAppBar({
    required this.profile,
    this.athleteProfile,
    required this.followersCount,
    required this.followingCount,
    required this.postsCount,
    required this.isOwn,
    required this.isFollowing,
    required this.onFollow,
    required this.onEdit,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 380,
      pinned: true,
      backgroundColor: AppColors.white,
      leading: isOwn
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
      actions: [
        if (isOwn)
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: onSettings,
          ),
        if (!isOwn)
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: _ProfileHeader(
          profile: profile,
          athleteProfile: athleteProfile,
          followersCount: followersCount,
          followingCount: followingCount,
          postsCount: postsCount,
          isOwn: isOwn,
          isFollowing: isFollowing,
          onFollow: onFollow,
          onEdit: onEdit,
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final ProfileModel profile;
  final AthleteProfileModel? athleteProfile;
  final int followersCount, followingCount, postsCount;
  final bool isOwn, isFollowing;
  final VoidCallback onFollow, onEdit;

  const _ProfileHeader({
    required this.profile,
    this.athleteProfile,
    required this.followersCount,
    required this.followingCount,
    required this.postsCount,
    required this.isOwn,
    required this.isFollowing,
    required this.onFollow,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      child: Column(
        children: [
          // Banner
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Banner image
              Container(
                height: 120,
                width: double.infinity,
                color: AppColors.primaryBg,
                child: profile.bannerUrl != null
                    ? CachedNetworkImage(
                        imageUrl: profile.bannerUrl!,
                        fit: BoxFit.cover,
                      )
                    : const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryLight],
                          ),
                        ),
                      ),
              ),

              // Avatar
              Positioned(
                bottom: -40,
                left: 20,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 4),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.primaryBg,
                    backgroundImage: profile.avatarUrl != null
                        ? CachedNetworkImageProvider(profile.avatarUrl!)
                        : null,
                    child: profile.avatarUrl == null
                        ? Text(
                            profile.fullName.isNotEmpty
                                ? profile.fullName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                ),
              ),

              // Talent Score
              if (athleteProfile != null)
                Positioned(
                  bottom: -40,
                  right: 20,
                  child: TalentScoreBadge(
                    score: athleteProfile!.talentScore,
                    size: 84,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 50),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom + badges
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                profile.fullName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              if (profile.isVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified, color: AppColors.primary, size: 18),
                              ],
                            ],
                          ),
                          Text(
                            '@${profile.username}',
                            style: const TextStyle(fontSize: 13, color: AppColors.grey400),
                          ),
                        ],
                      ),
                    ),
                    _KycBadge(level: profile.kycLevel),
                  ],
                ),
                const SizedBox(height: 8),

                // Sport + position + ville
                if (athleteProfile?.primarySportName != null)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _InfoChip(
                        icon: Icons.sports_soccer,
                        label: athleteProfile!.primarySportName!,
                        color: AppColors.primary,
                      ),
                      if (athleteProfile?.primaryPositionName != null)
                        _InfoChip(
                          icon: Icons.sports,
                          label: athleteProfile!.primaryPositionName!,
                          color: AppColors.primaryLight,
                        ),
                      if (profile.city != null)
                        _InfoChip(
                          icon: Icons.location_on_outlined,
                          label: profile.city!,
                          color: AppColors.grey500,
                        ),
                      if (profile.age > 0)
                        _InfoChip(
                          icon: Icons.cake_outlined,
                          label: '${profile.age} ans',
                          color: AppColors.grey500,
                        ),
                    ],
                  ),

                // Level + club
                if (athleteProfile?.level != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        athleteProfile!.levelLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentDark,
                        ),
                      ),
                    ),
                    if (athleteProfile?.currentClub != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.home_outlined, size: 14, color: AppColors.grey400),
                      const SizedBox(width: 3),
                      Text(
                        athleteProfile!.currentClub!,
                        style: const TextStyle(fontSize: 12, color: AppColors.grey500),
                      ),
                    ],
                  ]),
                ],

                // Bio
                if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    profile.bio!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.grey600,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 14),

                // Stats row
                Row(
                  children: [
                    _StatCount(count: postsCount, label: 'Publications'),
                    const SizedBox(width: 24),
                    _StatCount(count: followersCount, label: 'Abonnés'),
                    const SizedBox(width: 24),
                    _StatCount(count: followingCount, label: 'Abonnements'),
                    const Spacer(),
                    // Vues profil
                    Row(children: [
                      const Icon(Icons.visibility_outlined, size: 14, color: AppColors.grey400),
                      const SizedBox(width: 4),
                      Text('${profile.profileViews}',
                          style: const TextStyle(fontSize: 12, color: AppColors.grey400)),
                    ]),
                  ],
                ),

                const SizedBox(height: 14),

                // Badges : streak d'entraînement + vues recruteurs
                if (profile.currentStreak > 0 || profile.recruiterViewCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (profile.currentStreak > 0)
                          _MiniBadge(
                            icon: Icons.local_fire_department,
                            iconColor: AppColors.accentDark,
                            bg: AppColors.accentLight,
                            text: '${profile.currentStreak} j. d\'affilée',
                          ),
                        if (profile.recruiterViewCount > 0)
                          _MiniBadge(
                            icon: Icons.visibility,
                            iconColor: AppColors.primary,
                            bg: AppColors.primaryBg,
                            text: 'Vu par ${profile.recruiterViewCount} recruteur${profile.recruiterViewCount > 1 ? 's' : ''}',
                          ),
                      ],
                    ),
                  ),

                // Boutons action
                if (isOwn)
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Modifier le profil'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(40, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Icon(Icons.share_outlined, size: 18),
                    ),
                  ])
                else
                  Row(children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onFollow,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          backgroundColor: isFollowing ? AppColors.grey100 : AppColors.primary,
                          foregroundColor: isFollowing ? AppColors.grey700 : AppColors.white,
                        ),
                        child: Text(isFollowing ? 'Abonné ✓' : 'Suivre'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(40, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Icon(Icons.message_outlined, size: 18),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(40, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Icon(Icons.more_horiz, size: 18),
                    ),
                  ]),

                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab: Publications ─────────────────────────────────────
class _PostsTab extends StatelessWidget {
  final List<PostModel> posts;
  final List<AchievementModel> achievements;

  const _PostsTab({required this.posts, required this.achievements});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, size: 52, color: AppColors.grey300),
            SizedBox(height: 12),
            Text('Aucune publication', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.grey500)),
            SizedBox(height: 6),
            Text('Publiez votre première vidéo pour être détecté !', style: TextStyle(fontSize: 13, color: AppColors.grey400)),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // Palmarès (si présent)
        if (achievements.isNotEmpty)
          SliverToBoxAdapter(
            child: _AchievementsSection(achievements: achievements),
          ),

        // Grille vidéos
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _PostTile(post: posts[i]),
              childCount: posts.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.75,
            ),
          ),
        ),
      ],
    );
  }
}

class _PostTile extends StatefulWidget {
  final PostModel post;
  const _PostTile({required this.post});

  @override
  State<_PostTile> createState() => _PostTileState();
}

class _PostTileState extends State<_PostTile> {
  VideoPlayerController? _poster;
  bool _posterReady = false;

  PostModel get post => widget.post;
  String? get _mediaUrl => post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null;

  @override
  void initState() {
    super.initState();
    // Miniature = première image de la vidéo (si pas de thumbnail enregistrée).
    if (post.isVideo && post.thumbnailUrl == null && _mediaUrl != null) {
      _initPoster();
    }
  }

  Future<void> _initPoster() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(_mediaUrl!));
      await c.initialize();
      if (!mounted) { c.dispose(); return; }
      setState(() { _poster = c; _posterReady = true; });
    } catch (_) {/* on garde le placeholder */}
  }

  @override
  void dispose() {
    _poster?.dispose();
    super.dispose();
  }

  void _open() {
    final url = _mediaUrl;
    if (url == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FullScreenPost(post: post),
    ));
  }

  Widget _thumb() {
    // 1) thumbnail enregistrée
    if (post.thumbnailUrl != null) {
      return CachedNetworkImage(imageUrl: post.thumbnailUrl!, fit: BoxFit.cover);
    }
    // 2) image (post photo/status)
    if (!post.isVideo && _mediaUrl != null) {
      return CachedNetworkImage(imageUrl: _mediaUrl!, fit: BoxFit.cover);
    }
    // 3) vidéo : première frame comme poster
    if (post.isVideo && _posterReady && _poster != null) {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: _poster!.value.size.width,
          height: _poster!.value.size.height,
          child: VideoPlayer(_poster!),
        ),
      );
    }
    // 4) placeholder
    return Container(color: AppColors.primaryBg,
        child: const Center(child: Icon(Icons.play_circle_fill, color: AppColors.primary, size: 40)));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _open,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _thumb(),

            // Icône play au centre pour les vidéos
            if (post.isVideo)
              const Center(
                child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 42),
              ),

            // Overlay gradient
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)],
                ),
              ),
            ),

            // Badge « en attente de modération »
            if (post.status == 'pending_moderation')
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_top, color: Colors.white, size: 11),
                      SizedBox(width: 3),
                      Text('En attente',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),

            // Type badge
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      post.isVideo ? Icons.play_arrow : Icons.article_outlined,
                      color: Colors.white,
                      size: 12,
                    ),
                    if (post.durationLabel.isNotEmpty) ...[
                      const SizedBox(width: 2),
                      Text(post.durationLabel,
                          style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ],
                  ],
                ),
              ),
            ),

            // Infos bas
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  const Icon(Icons.favorite_border, color: Colors.white, size: 14),
                  const SizedBox(width: 3),
                  Text('${post.likesCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 11)),
                  const SizedBox(width: 10),
                  const Icon(Icons.visibility_outlined, color: Colors.white, size: 14),
                  const SizedBox(width: 3),
                  Text('${post.viewsCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Lecteur plein écran (vidéo / image) ───────────────────
class _FullScreenPost extends StatelessWidget {
  final PostModel post;
  const _FullScreenPost({required this.post});

  @override
  Widget build(BuildContext context) {
    final url = post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null;
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(post.title ?? (post.isVideo ? 'Vidéo' : 'Publication')),
      ),
      body: Center(
        child: url == null
            ? const Text('Média indisponible', style: TextStyle(color: Colors.white70))
            : post.isVideo
                ? AspectRatio(
                    aspectRatio: 9 / 16,
                    child: VideoPlayerWidget(videoUrl: url, autoPlay: true, showControls: true),
                  )
                : InteractiveViewer(
                    child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
                  ),
      ),
    );
  }
}

// ── Palmarès ──────────────────────────────────────────────
class _AchievementsSection extends StatelessWidget {
  final List<AchievementModel> achievements;
  const _AchievementsSection({required this.achievements});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Text('🏆 Palmarès',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
        ),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: achievements.length,
            itemBuilder: (_, i) {
              final a = achievements[i];
              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.ink),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(
                      [if (a.rank != null) a.rank, if (a.year != null) '${a.year}'].join(' · '),
                      style: const TextStyle(fontSize: 11, color: AppColors.accentDark),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Tab: Statistiques ─────────────────────────────────────
class _StatsTab extends StatelessWidget {
  final List<AthleteStatsModel> stats;
  final AthleteProfileModel? athleteProfile;
  const _StatsTab({required this.stats, this.athleteProfile});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Physique
          if (athleteProfile != null) ...[
            const Text('Profil Physique',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 12),
            _PhysicalCard(ap: athleteProfile!),
            const SizedBox(height: 20),
          ],

          // Stats de jeu
          if (stats.isNotEmpty) ...[
            const Text('Statistiques de Jeu',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 12),
            ...stats.map((s) => _StatCard(stat: s)),
          ] else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.bar_chart_outlined, size: 48, color: AppColors.grey300),
                    SizedBox(height: 12),
                    Text('Aucune statistique', style: TextStyle(color: AppColors.grey500)),
                    SizedBox(height: 6),
                    Text('Ajoutez vos statistiques de match.', style: TextStyle(fontSize: 12, color: AppColors.grey400)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhysicalCard extends StatelessWidget {
  final AthleteProfileModel ap;
  const _PhysicalCard({required this.ap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PhysicalStat(value: ap.heightCm != null ? '${ap.heightCm!.round()}cm' : '--', label: 'Taille', icon: '📏'),
              _PhysicalStat(value: ap.weightKg != null ? '${ap.weightKg!.round()}kg' : '--', label: 'Poids', icon: '⚖️'),
              _PhysicalStat(value: ap.yearsOfPractice != null ? '${ap.yearsOfPractice}ans' : '--', label: 'Expérience', icon: '⏱️'),
              _PhysicalStat(value: ap.dominantFoot == 'right' ? '🦵D' : ap.dominantFoot == 'left' ? '🦵G' : ap.dominantFoot == 'both' ? '🦵B' : '--', label: 'Pied fort', icon: ''),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: AppColors.grey200),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: AppColors.grey400),
              const SizedBox(width: 6),
              Text(ap.availabilityLabel, style: const TextStyle(fontSize: 12, color: AppColors.grey500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhysicalStat extends StatelessWidget {
  final String value, label, icon;
  const _PhysicalStat({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (icon.isNotEmpty) Text(icon, style: const TextStyle(fontSize: 18)),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.grey400)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final AthleteStatsModel stat;
  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(stat.season ?? 'Saison actuelle',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            if (stat.verified)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(4)),
                child: const Text('Vérifié ✓', style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w600)),
              ),
            const Spacer(),
            if (stat.competition != null)
              Text(stat.competition!, style: const TextStyle(fontSize: 12, color: AppColors.grey400)),
          ]),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(value: '${stat.matchesPlayed}', label: 'Matchs'),
              _StatItem(value: '${stat.wins}', label: 'Victoires'),
              _StatItem(value: '${stat.losses}', label: 'Défaites'),
              _StatItem(value: '${stat.draws}', label: 'Nuls'),
            ],
          ),
          // Stats sport-spécifiques
          if (stat.sportStats.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.grey200),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: stat.sportStats.entries
                  .take(6)
                  .map((e) => _StatItem(
                        value: '${e.value}',
                        label: e.key.replaceAll('_', ' '),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value, label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.grey400)),
      ],
    );
  }
}

// ── Tab: Évaluations ──────────────────────────────────────
class _RatingsTab extends StatelessWidget {
  final List<ExpertRatingModel> ratings;
  const _RatingsTab({required this.ratings});

  @override
  Widget build(BuildContext context) {
    if (ratings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_outline, size: 52, color: AppColors.grey300),
            SizedBox(height: 12),
            Text('Aucune évaluation', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.grey500)),
            SizedBox(height: 6),
            Text('Les experts noteront vos performances.', style: TextStyle(fontSize: 12, color: AppColors.grey400)),
          ],
        ),
      );
    }

    // Score moyen
    final avgScore = ratings.map((r) => r.globalScore).reduce((a, b) => a + b) / ratings.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score global
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                TalentScoreBadge(score: avgScore * 10, size: 90),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Score moyen', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('${avgScore.toStringAsFixed(1)}/10',
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                      Text('${ratings.length} évaluation${ratings.length > 1 ? 's' : ''} d\'experts',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Critères moyens
          const Text('Détail par critère',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 12),
          _CriteriaBreakdown(ratings: ratings),
          const SizedBox(height: 20),

          // Avis individuels
          const Text('Avis des experts',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 12),
          ...ratings.map((r) => _ExpertCard(rating: r)),
        ],
      ),
    );
  }
}

class _CriteriaBreakdown extends StatelessWidget {
  final List<ExpertRatingModel> ratings;
  const _CriteriaBreakdown({required this.ratings});

  double _avg(double Function(ExpertRatingModel) getter) {
    if (ratings.isEmpty) return 0;
    return ratings.map(getter).reduce((a, b) => a + b) / ratings.length;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        children: [
          TalentScoreBar(score: _avg((r) => r.techniqueScore), label: 'Technique', color: AppColors.primary),
          const SizedBox(height: 12),
          TalentScoreBar(score: _avg((r) => r.physicalScore), label: 'Physique', color: AppColors.blue),
          const SizedBox(height: 12),
          TalentScoreBar(score: _avg((r) => r.mentalScore), label: 'Mental / Attitude', color: AppColors.success),
          const SizedBox(height: 12),
          TalentScoreBar(score: _avg((r) => r.statsScore), label: 'Statistiques', color: AppColors.accent),
          const SizedBox(height: 12),
          TalentScoreBar(score: _avg((r) => r.potentialScore), label: 'Potentiel', color: AppColors.warning),
        ],
      ),
    );
  }
}

class _ExpertCard extends StatelessWidget {
  final ExpertRatingModel rating;
  const _ExpertCard({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryBg,
                backgroundImage: rating.expertAvatarUrl != null
                    ? CachedNetworkImageProvider(rating.expertAvatarUrl!)
                    : null,
                child: rating.expertAvatarUrl == null
                    ? Text(
                        (rating.expertName ?? 'E')[0],
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rating.expertName ?? 'Expert',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      timeago.format(rating.createdAt, locale: 'fr'),
                      style: const TextStyle(fontSize: 11, color: AppColors.grey400),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${rating.globalScore.toStringAsFixed(1)} ⭐',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.accentDark,
                  ),
                ),
              ),
            ],
          ),
          if (rating.comment != null && rating.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              rating.comment!,
              style: const TextStyle(fontSize: 13, color: AppColors.grey600, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Widgets utilitaires ───────────────────────────────────

class _KycBadge extends StatelessWidget {
  final String level;
  const _KycBadge({required this.level});

  Color get _color {
    switch (level) {
      case 'full':     return AppColors.kycGold;
      case 'identity': return AppColors.kycSilver;
      case 'phone':    return AppColors.kycBronze;
      default:         return AppColors.grey300;
    }
  }

  String get _label {
    switch (level) {
      case 'full':     return '✓ Certifié';
      case 'identity': return '✓ Vérifié';
      case 'phone':    return '✓ Basique';
      default:         return 'Non vérifié';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (level == 'none' || level == 'email') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(_label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _color)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _StatCount extends StatelessWidget {
  final int count;
  final String label;
  const _StatCount({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$count',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.grey400)),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bg;
  final String text;
  const _MiniBadge({
    required this.icon,
    required this.iconColor,
    required this.bg,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: iconColor)),
        ],
      ),
    );
  }
}

