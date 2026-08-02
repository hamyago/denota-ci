// lib/presentation/widgets/video/video_player_widget.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final bool autoPlay;
  final bool showControls;
  final double? aspectRatio;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.autoPlay = false,
    this.showControls = true,
    this.aspectRatio,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _vpCtrl;
  ChewieController? _chewieCtrl;
  bool _initialized = false;
  bool _error = false;
  bool _started = false;

  Future<void> _init() async {
    if (_started) return;
    setState(() => _started = true);
    try {
      final vpc = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await vpc.initialize();
      if (!mounted) { vpc.dispose(); return; }

      final cc = ChewieController(
        videoPlayerController: vpc,
        autoPlay: widget.autoPlay,
        looping: false,
        aspectRatio: widget.aspectRatio ?? vpc.value.aspectRatio,
        placeholder: widget.thumbnailUrl != null
            ? CachedNetworkImage(imageUrl: widget.thumbnailUrl!, fit: BoxFit.cover)
            : null,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.accent,
          handleColor: AppColors.accent,
          bufferedColor: AppColors.grey400,
          backgroundColor: AppColors.grey200,
        ),
        showControls: widget.showControls,
      );

      setState(() {
        _vpCtrl = vpc;
        _chewieCtrl = cc;
        _initialized = true;
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _chewieCtrl?.dispose();
    _vpCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) return _ErrorView();

    if (!_started) {
      // Thumbnail avec bouton play
      return GestureDetector(
        onTap: _init,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.thumbnailUrl != null)
              CachedNetworkImage(imageUrl: widget.thumbnailUrl!, fit: BoxFit.cover)
            else
              Container(color: AppColors.primaryBg),
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
              ),
            ),
          ],
        ),
      );
    }

    if (!_initialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (widget.thumbnailUrl != null)
            CachedNetworkImage(imageUrl: widget.thumbnailUrl!, fit: BoxFit.cover),
          const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        ],
      );
    }

    return Chewie(controller: _chewieCtrl!);
  }
}

class _ErrorView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryBg,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppColors.grey400, size: 36),
            SizedBox(height: 8),
            Text('Impossible de charger la vidéo', style: TextStyle(color: AppColors.grey400, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ── Feed Video Card ────────────────────────────────────────
class FeedVideoCard extends StatelessWidget {
  final String authorName;
  final String? authorAvatarUrl;
  final String authorSport;
  final double talentScore;
  final String videoUrl;
  final String? imageUrl;
  final String contentType;
  final String? thumbnailUrl;
  final String? title;
  final String? body;
  final int likesCount;
  final int commentsCount;
  final int viewsCount;
  final String timeAgo;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final bool isLiked;

  const FeedVideoCard({
    super.key,
    required this.authorName,
    this.authorAvatarUrl,
    required this.authorSport,
    required this.talentScore,
    required this.videoUrl,
    this.imageUrl,
    this.contentType = 'video',
    this.thumbnailUrl,
    this.title,
    this.body,
    required this.likesCount,
    required this.commentsCount,
    required this.viewsCount,
    required this.timeAgo,
    this.onAuthorTap,
    this.onLike,
    this.onComment,
    this.onShare,
    this.isLiked = false,
  });

  // Affiche le bon média selon le type de contenu :
  // vidéo -> lecteur ; image/status -> image ; sinon -> rien.
  Widget _buildMedia() {
    final isVideo = contentType == 'video' && videoUrl.isNotEmpty;
    if (isVideo) {
      return ClipRRect(
        borderRadius: BorderRadius.zero,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: VideoPlayerWidget(
            videoUrl: videoUrl,
            thumbnailUrl: thumbnailUrl,
          ),
        ),
      );
    }

    final pic = (imageUrl != null && imageUrl!.isNotEmpty)
        ? imageUrl!
        : (videoUrl.isNotEmpty ? videoUrl : null);
    if (pic != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: CachedNetworkImage(
          imageUrl: pic,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            height: 220,
            color: AppColors.grey200,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (_, __, ___) => Container(
            height: 220,
            color: AppColors.grey200,
            child: const Center(child: Icon(Icons.broken_image, color: AppColors.grey400)),
          ),
        ),
      );
    }

    // Pas de média (post texte pur) : on n'affiche rien.
    return const SizedBox.shrink();
  }

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
          // ── Header ──────────────────────────────────
          GestureDetector(
            onTap: onAuthorTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primaryBg,
                    backgroundImage: authorAvatarUrl != null
                        ? CachedNetworkImageProvider(authorAvatarUrl!)
                        : null,
                    child: authorAvatarUrl == null
                        ? Text(authorName[0].toUpperCase(),
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 15))
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(authorName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.ink)),
                        Row(children: [
                          Text(authorSport,
                              style: const TextStyle(fontSize: 12, color: AppColors.grey500)),
                          const Text(' · ', style: TextStyle(color: AppColors.grey400)),
                          Text(timeAgo,
                              style: const TextStyle(fontSize: 12, color: AppColors.grey400)),
                        ]),
                      ],
                    ),
                  ),
                  // Talent Score badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('⭐', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 2),
                        Text(talentScore.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentDark)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Média (vidéo / image / aucun) ─────────────
          _buildMedia(),

          // ── Titre & description ───────────────────────
          if (title != null || body != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(title!,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (body != null) ...[
                    const SizedBox(height: 4),
                    Text(body!,
                        style: const TextStyle(fontSize: 13, color: AppColors.grey500, height: 1.4),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),

          // ── Actions ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(
              children: [
                // Like
                _ActionBtn(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  label: _formatCount(likesCount),
                  color: isLiked ? AppColors.error : AppColors.grey500,
                  onTap: onLike,
                ),
                // Comment
                _ActionBtn(
                  icon: Icons.chat_bubble_outline,
                  label: _formatCount(commentsCount),
                  color: AppColors.grey500,
                  onTap: onComment,
                ),
                const Spacer(),
                // Vues
                Row(children: [
                  const Icon(Icons.visibility_outlined, size: 14, color: AppColors.grey300),
                  const SizedBox(width: 4),
                  Text(_formatCount(viewsCount),
                      style: const TextStyle(fontSize: 12, color: AppColors.grey300)),
                ]),
                const SizedBox(width: 8),
                // Partager
                _ActionBtn(
                  icon: Icons.share_outlined,
                  label: '',
                  color: AppColors.grey500,
                  onTap: onShare,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
            ],
          ],
        ),
      ),
    );
  }
}
