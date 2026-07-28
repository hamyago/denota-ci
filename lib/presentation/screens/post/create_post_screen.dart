// lib/presentation/screens/post/create_post_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_compress/video_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/video_service.dart';
import '../../../main.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _videoService = VideoService();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _videoService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nouvelle publication'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.grey400,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.videocam_outlined), text: 'Vidéo'),
            Tab(icon: Icon(Icons.article_outlined),  text: 'Article'),
            Tab(icon: Icon(Icons.bolt_outlined),     text: 'Statut'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _VideoPostTab(videoService: _videoService),
          _ArticlePostTab(videoService: _videoService),
          _StatusPostTab(videoService: _videoService),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TAB VIDÉO
// ══════════════════════════════════════════════════════════════
class _VideoPostTab extends StatefulWidget {
  final VideoService videoService;
  const _VideoPostTab({required this.videoService});

  @override
  State<_VideoPostTab> createState() => _VideoPostTabState();
}

class _VideoPostTabState extends State<_VideoPostTab> {
  VideoPickResult? _picked;
  VideoPlayerController? _playerCtrl;
  bool _compressing = false;
  double _compressProgress = 0;
  bool _uploading = false;
  UploadProgress? _uploadProgress;

  final _titleCtrl  = TextEditingController();
  final _bodyCtrl   = TextEditingController();
  final _tagCtrl    = TextEditingController();
  List<String> _tags = [];
  int? _sportId;
  String _quality = 'medium';

  final _sports = const [
    {'id': 1, 'name': 'Football'},
    {'id': 2, 'name': 'Basketball'},
    {'id': 3, 'name': 'Athlétisme'},
    {'id': 4, 'name': 'Natation'},
    {'id': 5, 'name': 'Handball'},
    {'id': 9, 'name': 'Arts Martiaux'},
    {'id': 10,'name': 'Taekwondo'},
    {'id': 11,'name': 'Boxe'},
  ];

  @override
  void dispose() {
    _playerCtrl?.dispose();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickVideo(ImageSource source) async {
    final result = await widget.videoService.pickVideo(source: source);
    if (result == null || !mounted) return;

    // Init lecteur vidéo
    final ctrl = VideoPlayerController.file(result.file);
    await ctrl.initialize();
    ctrl.setLooping(true);

    setState(() {
      _picked = result;
      _playerCtrl?.dispose();
      _playerCtrl = ctrl;
    });
  }

  void _showPickerModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Choisir une vidéo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _PickerOption(
              icon: Icons.photo_library_outlined,
              label: 'Galerie',
              subtitle: 'Importer depuis votre téléphone',
              onTap: () { Navigator.pop(context); _pickVideo(ImageSource.gallery); },
            ),
            _PickerOption(
              icon: Icons.videocam_outlined,
              label: 'Caméra',
              subtitle: 'Filmer directement',
              onTap: () { Navigator.pop(context); _pickVideo(ImageSource.camera); },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _publish() async {
    if (_picked == null) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() { _uploading = true; _uploadProgress = null; });

    // Compression si demandée
    File fileToUpload = _picked!.file;
    if (_quality != 'original') {
      setState(() { _compressing = true; _compressProgress = 0; });
      fileToUpload = await widget.videoService.compressVideo(
        _picked!.file,
        quality: _quality == 'high'
            ? VideoQuality.HighestQuality
            : VideoQuality.MediumQuality,
        onProgress: (p) => setState(() => _compressProgress = p),
      );
      setState(() => _compressing = false);
    }

    // Upload avec progression
    final stream = widget.videoService.uploadVideo(
      videoFile: fileToUpload,
      thumbnailFile: _picked!.thumbnail,
      authorId: user.id,
      contentType: 'video',
      title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
      tags: _tags,
      sportId: _sportId,
      durationSec: _picked!.durationMs != null ? _picked!.durationMs! ~/ 1000 : null,
    );

    await for (final progress in stream) {
      if (!mounted) break;
      setState(() => _uploadProgress = progress);
      if (progress.done) {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎬 Vidéo publiée ! En attente de modération.'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }
      if (progress.error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : ${progress.error}'), backgroundColor: AppColors.error),
          );
          setState(() => _uploading = false);
        }
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Zone vidéo ────────────────────────────────
          if (_picked == null)
            _VideoDropZone(onPick: _showPickerModal)
          else
            _VideoPreview(
              result: _picked!,
              controller: _playerCtrl,
              onReplace: _showPickerModal,
            ),

          const SizedBox(height: 20),

          // ── Progression upload ─────────────────────────
          if (_uploading) ...[
            if (_compressing)
              _ProgressCard(
                icon: Icons.compress,
                label: 'Compression vidéo...',
                percent: _compressProgress,
                color: AppColors.blue,
              )
            else if (_uploadProgress != null)
              _ProgressCard(
                icon: Icons.cloud_upload_outlined,
                label: _uploadProgress!.label,
                percent: _uploadProgress!.percent,
                color: AppColors.primary,
              ),
            const SizedBox(height: 16),
          ],

          // ── Formulaire ─────────────────────────────────
          if (!_uploading) ...[
            // Sport
            DropdownButtonFormField<int>(
              value: _sportId,
              decoration: const InputDecoration(
                labelText: 'Sport concerné',
                prefixIcon: Icon(Icons.sports_outlined),
              ),
              items: _sports.map((s) => DropdownMenuItem<int>(
                value: s['id'] as int,
                child: Text(s['name'] as String),
              )).toList(),
              onChanged: (v) => setState(() => _sportId = v),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Titre (optionnel)',
                hintText: 'Ex : Ma meilleure prestation de la saison',
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _bodyCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Décrivez votre performance, le contexte du match...',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 12),

            // Tags
            _TagsInput(
              tags: _tags,
              controller: _tagCtrl,
              onAdd: (tag) {
                if (tag.isNotEmpty && !_tags.contains(tag) && _tags.length < 10) {
                  setState(() => _tags.add(tag));
                  _tagCtrl.clear();
                }
              },
              onRemove: (tag) => setState(() => _tags.remove(tag)),
            ),
            const SizedBox(height: 16),

            // Qualité
            _QualitySelector(
              value: _quality,
              onChanged: (v) => setState(() => _quality = v),
              originalSizeMb: _picked?.fileSizeMb ?? 0,
            ),
            const SizedBox(height: 24),

            // Infos légales
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.infoBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outlined, color: AppColors.info, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Votre vidéo sera examinée par notre équipe avant publication. '
                      'Durée : 24h max. Assurez-vous d\'avoir les droits sur le contenu.',
                      style: TextStyle(fontSize: 12, color: AppColors.blue, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bouton publier
            ElevatedButton.icon(
              onPressed: _picked == null ? null : _publish,
              icon: const Icon(Icons.publish),
              label: const Text('Publier la vidéo'),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TAB ARTICLE
// ══════════════════════════════════════════════════════════════
class _ArticlePostTab extends StatefulWidget {
  final VideoService videoService;
  const _ArticlePostTab({required this.videoService});

  @override
  State<_ArticlePostTab> createState() => _ArticlePostTabState();
}

class _ArticlePostTabState extends State<_ArticlePostTab> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();
  List<File> _images = [];
  bool _loading = false;

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 85);
    if (files.isNotEmpty) {
      setState(() => _images = files.take(5).map((f) => File(f.path)).toList());
    }
  }

  Future<void> _publish() async {
    if (_bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rédigez votre article d\'abord.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.videoService.createTextPost(
        authorId:    supabase.auth.currentUser!.id,
        contentType: 'article',
        title:       _titleCtrl.text.trim(),
        body:        _bodyCtrl.text.trim(),
        imageFiles:  _images,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Article publié !'), backgroundColor: AppColors.success),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _titleCtrl,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink),
            decoration: const InputDecoration(
              hintText: 'Titre de l\'article...',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
            maxLines: null,
          ),
          const Divider(color: AppColors.grey200),
          const SizedBox(height: 8),
          TextFormField(
            controller: _bodyCtrl,
            maxLines: null,
            minLines: 12,
            style: const TextStyle(fontSize: 15, height: 1.7, color: AppColors.grey700),
            decoration: const InputDecoration(
              hintText: 'Rédigez votre article ici...\n\nPartagez votre expérience, votre parcours, vos conseils...',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
          const SizedBox(height: 16),

          // Images
          if (_images.isNotEmpty) ...[
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                itemBuilder: (_, i) => Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 90, height: 90,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_images[i], fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: 4, right: 14,
                      child: GestureDetector(
                        onTap: () => setState(() => _images.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.image_outlined, size: 16),
                label: const Text('Ajouter des photos'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
              ),
              const Spacer(),
              Text('${_bodyCtrl.text.length} caractères',
                  style: const TextStyle(fontSize: 12, color: AppColors.grey400)),
            ],
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: _loading ? null : _publish,
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.publish),
            label: const Text('Publier l\'article'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TAB STATUT
// ══════════════════════════════════════════════════════════════
class _StatusPostTab extends StatefulWidget {
  final VideoService videoService;
  const _StatusPostTab({required this.videoService});

  @override
  State<_StatusPostTab> createState() => _StatusPostTabState();
}

class _StatusPostTabState extends State<_StatusPostTab> {
  final _bodyCtrl = TextEditingController();
  File? _image;
  bool _loading = false;
  String _mood = '';

  final _moods = ['🔥', '💪', '🎯', '🏆', '😤', '🙏', '⚽', '🏀', '🥊'];

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) setState(() => _image = File(file.path));
  }

  Future<void> _publish() async {
    if (_bodyCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final text = _mood.isEmpty ? _bodyCtrl.text.trim() : '$_mood ${_bodyCtrl.text.trim()}';
      await widget.videoService.createTextPost(
        authorId:    supabase.auth.currentUser!.id,
        contentType: 'status',
        body:        text,
        imageFiles:  _image != null ? [_image!] : [],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Statut publié !'), backgroundColor: AppColors.success),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Humeur / emoji
          const Text('Humeur du jour',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.grey500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _moods.map((m) => GestureDetector(
              onTap: () => setState(() => _mood = _mood == m ? '' : m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _mood == m ? AppColors.accentLight : AppColors.grey100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _mood == m ? AppColors.accent : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Text(m, style: const TextStyle(fontSize: 24)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 20),

          // Texte
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.grey200),
            ),
            child: Column(
              children: [
                if (_mood.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_mood, style: const TextStyle(fontSize: 28)),
                  ),
                TextFormField(
                  controller: _bodyCtrl,
                  maxLines: 5,
                  maxLength: 280,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                  decoration: const InputDecoration(
                    hintText: 'Partagez une actualité, une victoire, un objectif...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                // Image preview
                if (_image != null) ...[
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_image!, height: 160, width: double.infinity, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 8, right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _image = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              IconButton(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_outlined, color: AppColors.primary),
                tooltip: 'Ajouter une photo',
              ),
              const Spacer(),
              Text(
                '${_bodyCtrl.text.length}/280',
                style: TextStyle(
                  fontSize: 12,
                  color: _bodyCtrl.text.length > 250 ? AppColors.error : AppColors.grey400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: (_loading || _bodyCtrl.text.trim().isEmpty) ? null : _publish,
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_outlined),
            label: const Text('Publier le statut'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// WIDGETS UTILITAIRES
// ══════════════════════════════════════════════════════════════

class _VideoDropZone extends StatelessWidget {
  final VoidCallback onPick;
  const _VideoDropZone({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.primaryBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 2, style: BorderStyle.solid),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 52, color: AppColors.primary),
            SizedBox(height: 12),
            Text('Sélectionner une vidéo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary)),
            SizedBox(height: 6),
            Text('Depuis la galerie ou la caméra', style: TextStyle(fontSize: 12, color: AppColors.grey400)),
            SizedBox(height: 16),
            Text('MP4 · MOV · Max 500 Mo · Max 5 minutes', style: TextStyle(fontSize: 11, color: AppColors.grey300)),
          ],
        ),
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  final VideoPickResult result;
  final VideoPlayerController? controller;
  final VoidCallback onReplace;
  const _VideoPreview({required this.result, this.controller, required this.onReplace});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  bool _playing = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Vidéo ou thumbnail
              widget.controller != null && widget.controller!.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: widget.controller!.value.aspectRatio,
                      child: VideoPlayer(widget.controller!),
                    )
                  : widget.result.thumbnail != null
                      ? Image.file(widget.result.thumbnail!, height: 220, width: double.infinity, fit: BoxFit.cover)
                      : Container(height: 220, color: AppColors.primaryBg),

              // Play/pause
              GestureDetector(
                onTap: () {
                  setState(() => _playing = !_playing);
                  _playing ? widget.controller?.play() : widget.controller?.pause();
                },
                child: AnimatedOpacity(
                  opacity: _playing ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                  ),
                ),
              ),

              // Info overlay
              Positioned(
                bottom: 10, left: 10, right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.videocam, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(widget.result.durationLabel, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      const Spacer(),
                      Text('${widget.result.fileSizeMb.toStringAsFixed(1)} Mo', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ),

              // Bouton changer
              Positioned(
                top: 10, right: 10,
                child: GestureDetector(
                  onTap: widget.onReplace,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.swap_horiz, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Avertissement taille
        if (widget.result.fileSizeMb > 100) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_outlined, color: AppColors.warning, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Fichier lourd (${widget.result.fileSizeMb.toStringAsFixed(0)} Mo). Privilégiez la compression.',
                    style: const TextStyle(fontSize: 12, color: AppColors.warning),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final double percent;
  final Color color;
  const _ProgressCard({required this.icon, required this.label, required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
              Text('${(percent * 100).round()}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              backgroundColor: AppColors.grey200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _QualitySelector extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;
  final double originalSizeMb;
  const _QualitySelector({required this.value, required this.onChanged, required this.originalSizeMb});

  @override
  Widget build(BuildContext context) {
    final options = [
      {'value': 'original', 'label': 'Original', 'desc': '${originalSizeMb.toStringAsFixed(0)} Mo', 'icon': '📁'},
      {'value': 'high',     'label': 'Haute qualité', 'desc': '~${(originalSizeMb * 0.6).toStringAsFixed(0)} Mo', 'icon': '🎬'},
      {'value': 'medium',   'label': 'Équilibré', 'desc': '~${(originalSizeMb * 0.35).toStringAsFixed(0)} Mo', 'icon': '⚡'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Qualité d\'upload', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.grey500)),
        const SizedBox(height: 8),
        Row(
          children: options.map((o) {
            final selected = value == o['value'];
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(o['value'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primaryBg : AppColors.grey100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppColors.primary : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(o['icon'] as String, style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 2),
                      Text(o['label'] as String,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                              color: selected ? AppColors.primary : AppColors.grey600)),
                      Text(o['desc'] as String,
                          style: const TextStyle(fontSize: 10, color: AppColors.grey400)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _TagsInput extends StatelessWidget {
  final List<String> tags;
  final TextEditingController controller;
  final void Function(String) onAdd;
  final void Function(String) onRemove;
  const _TagsInput({required this.tags, required this.controller, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Tags',
                  hintText: 'Ex: sprint, finale, U18...',
                  prefixIcon: Icon(Icons.tag),
                ),
                onFieldSubmitted: onAdd,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => onAdd(controller.text.trim()),
              style: ElevatedButton.styleFrom(minimumSize: const Size(52, 52)),
              child: const Icon(Icons.add),
            ),
          ],
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: tags.map((t) => Chip(
              label: Text('#$t', style: const TextStyle(fontSize: 12)),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () => onRemove(t),
              backgroundColor: AppColors.primaryBg,
              side: BorderSide.none,
              labelStyle: const TextStyle(color: AppColors.primary),
            )).toList(),
          ),
        ],
      ],
    );
  }
}

class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final VoidCallback onTap;
  const _PickerOption({required this.icon, required this.label, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: AppColors.primaryBg, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
    );
  }
}
