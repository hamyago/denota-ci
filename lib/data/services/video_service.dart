// lib/data/services/video_service.dart
//
// Compression vidéo retirée (video_compress nécessite NDK natif C++
// incompatible avec le CI GitHub). La vidéo est uploadée telle quelle.
// TODO: réintégrer video_compress quand le build local sera disponible,
// ou migrer vers ffmpeg_kit_flutter si besoin.
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class VideoPickResult {
  final File file;
  final File? thumbnail;
  final int? durationMs;
  final int fileSizeBytes;

  const VideoPickResult({
    required this.file,
    this.thumbnail,
    this.durationMs,
    required this.fileSizeBytes,
  });

  String get durationLabel {
    if (durationMs == null) return '';
    final sec = durationMs! ~/ 1000;
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  double get fileSizeMb => fileSizeBytes / (1024 * 1024);
}

class UploadProgress {
  final double percent; // 0.0 → 1.0
  final String label;
  final bool done;
  final String? error;

  const UploadProgress({
    required this.percent,
    required this.label,
    this.done = false,
    this.error,
  });
}

class VideoService {
  final _picker = ImagePicker();
  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  // ── Sélection depuis galerie ou caméra ─────────────────
  Future<VideoPickResult?> pickVideo({
    required ImageSource source,
    Duration maxDuration = const Duration(minutes: 5),
  }) async {
    final xfile = await _picker.pickVideo(
      source: source,
      maxDuration: maxDuration,
    );
    if (xfile == null) return null;

    final file = File(xfile.path);
    final stat = await file.stat();

    return VideoPickResult(
      file: file,
      thumbnail: null, // thumbnail via video_compress retiré
      durationMs: null,
      fileSizeBytes: stat.size,
    );
  }

  // ── Compression (no-op sans video_compress) ───────────
  Future<File> compressVideo(
    File file, {
    dynamic quality,
    void Function(double)? onProgress,
  }) async {
    // Sans video_compress, on retourne le fichier tel quel.
    // La compression se fera côté serveur ou au prochain sprint.
    onProgress?.call(1.0);
    return file;
  }

  // ── Upload vers Supabase Storage ───────────────────────
  Stream<UploadProgress> uploadVideo({
    required File videoFile,
    required File? thumbnailFile,
    required String authorId,
    required String contentType,
    String? title,
    String? body,
    List<String> tags = const [],
    int? sportId,
    int? durationSec,
  }) async* {
    final videoId = _uuid.v4();
    final videoExt = videoFile.path.split('.').last;
    final videoPath = '$authorId/$videoId.$videoExt';

    try {
      yield const UploadProgress(percent: 0.05, label: 'Préparation de la vidéo...');

      final videoBytes = await videoFile.readAsBytes();
      final videoSizeMb = videoBytes.length / (1024 * 1024);

      yield UploadProgress(
        percent: 0.10,
        label: 'Upload de la vidéo (${videoSizeMb.toStringAsFixed(1)} Mo)...',
      );

      await _supabase.storage.from('videos').uploadBinary(
        videoPath,
        videoBytes,
        fileOptions: FileOptions(
          contentType: 'video/$videoExt',
          upsert: false,
        ),
      );

      final videoUrl = _supabase.storage.from('videos').getPublicUrl(videoPath);

      yield const UploadProgress(percent: 0.65, label: 'Vidéo uploadée ✓');

      // ── Upload thumbnail ─────────────────────────────
      String? thumbUrl;
      if (thumbnailFile != null) {
        yield const UploadProgress(percent: 0.70, label: 'Upload de la miniature...');

        final thumbPath = '$authorId/${videoId}_thumb.jpg';
        final thumbBytes = await thumbnailFile.readAsBytes();

        await _supabase.storage.from('posts').uploadBinary(
          thumbPath,
          thumbBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
        );

        thumbUrl = _supabase.storage.from('posts').getPublicUrl(thumbPath);
        yield const UploadProgress(percent: 0.80, label: 'Miniature uploadée ✓');
      }

      // ── Enregistrement en base ────────────────────────
      yield const UploadProgress(percent: 0.85, label: 'Enregistrement de la publication...');

      await _supabase.from('posts').insert({
        'author_id': authorId,
        'content_type': contentType,
        'status': 'pending_moderation',
        'title': title,
        'body': body,
        'tags': tags,
        'sport_id': sportId,
        'media_urls': [videoUrl],
        'thumbnail_url': thumbUrl,
        'duration_sec': durationSec,
        'published_at': DateTime.now().toIso8601String(),
      });

      yield const UploadProgress(
        percent: 1.0,
        label: 'Publication envoyée en modération ✓',
        done: true,
      );
    } catch (e) {
      yield UploadProgress(
        percent: 0,
        label: 'Erreur : $e',
        error: e.toString(),
      );
    }
  }

  // ── Upload article / statut (sans vidéo) ──────────────
  Future<void> createTextPost({
    required String authorId,
    required String contentType,
    required String body,
    String? title,
    List<String> tags = const [],
    int? sportId,
    List<File> imageFiles = const [],
  }) async {
    List<String> mediaUrls = [];

    for (int i = 0; i < imageFiles.length; i++) {
      final ext = imageFiles[i].path.split('.').last;
      final path = '$authorId/${const Uuid().v4()}.$ext';
      final bytes = await imageFiles[i].readAsBytes();
      await _supabase.storage.from('posts').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: 'image/$ext', upsert: false),
      );
      mediaUrls.add(_supabase.storage.from('posts').getPublicUrl(path));
    }

    await _supabase.from('posts').insert({
      'author_id': authorId,
      'content_type': contentType,
      'status': 'pending_moderation',
      'title': title,
      'body': body,
      'tags': tags,
      'sport_id': sportId,
      'media_urls': mediaUrls,
      'published_at': DateTime.now().toIso8601String(),
    });
  }

  void dispose() {
    // Rien à disposer sans video_compress
  }
}
