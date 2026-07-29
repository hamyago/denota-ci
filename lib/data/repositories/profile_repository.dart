// lib/data/repositories/profile_repository.dart
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

/// Extension → type MIME accepté par les buckets avatars/banners
/// (image/jpeg et non image/jpg, sinon l'upload est refusé).
String _imageMime(String ext) {
  switch (ext.toLowerCase()) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'jpg':
    case 'jpeg':
    default:
      return 'image/jpeg';
  }
}

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ── Profil de base ─────────────────────────────────────

  Future<ProfileModel?> getProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return ProfileModel.fromJson(data);
  }

  Future<ProfileModel?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return getProfile(user.id);
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Non connecté');
    await _client.from('profiles').update(data).eq('id', user.id);
  }

  // ── Profil athlète ─────────────────────────────────────

  Future<AthleteProfileModel?> getAthleteProfile(String userId) async {
    final data = await _client
        .from('athlete_profiles')
        .select('''
          *,
          sports(name_fr),
          positions(name_fr)
        ''')
        .eq('profile_id', userId)
        .maybeSingle();
    if (data == null) return null;
    // Flatten nested data
    final flat = Map<String, dynamic>.from(data);
    flat['sport_name'] = data['sports']?['name_fr'];
    flat['position_name'] = data['positions']?['name_fr'];
    return AthleteProfileModel.fromJson(flat);
  }

  Future<void> upsertAthleteProfile(Map<String, dynamic> data) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Non connecté');
    data['profile_id'] = user.id;
    await _client.from('athlete_profiles').upsert(data);
  }

  // ── Avatar & Banner Upload ──────────────────────────────

  Future<String> uploadAvatar(File file) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Non connecté');
    final ext = file.path.split('.').last.toLowerCase();
    final path = '${user.id}/avatar.$ext';
    await _client.storage.from('avatars').upload(
      path, file,
      fileOptions: FileOptions(upsert: true, contentType: _imageMime(ext)),
    );
    // Cache-busting : force le rechargement de l'image après ré-upload
    return '${_client.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> uploadBanner(File file) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Non connecté');
    final ext = file.path.split('.').last.toLowerCase();
    final path = '${user.id}/banner.$ext';
    await _client.storage.from('banners').upload(
      path, file,
      fileOptions: FileOptions(upsert: true, contentType: _imageMime(ext)),
    );
    return '${_client.storage.from('banners').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  // ── Statistiques ───────────────────────────────────────

  Future<List<AthleteStatsModel>> getAthleteStats(String userId) async {
    final data = await _client
        .from('athlete_stats')
        .select()
        .eq('athlete_id', userId)
        .order('season', ascending: false);
    return (data as List)
        .map((e) => AthleteStatsModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addStats(Map<String, dynamic> data) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Non connecté');
    data['athlete_id'] = user.id;
    await _client.from('athlete_stats').insert(data);
  }

  // ── Notations experts ──────────────────────────────────

  Future<List<ExpertRatingModel>> getExpertRatings(String userId) async {
    final data = await _client
        .from('expert_ratings')
        .select('''
          *,
          expert:profiles!expert_id(full_name, avatar_url)
        ''')
        .eq('athlete_id', userId)
        .eq('is_public', true)
        .order('created_at', ascending: false);

    return (data as List).map((e) {
      final flat = Map<String, dynamic>.from(e as Map<String, dynamic>);
      flat['expert_name']       = e['expert']?['full_name'];
      flat['expert_avatar_url'] = e['expert']?['avatar_url'];
      return ExpertRatingModel.fromJson(flat);
    }).toList();
  }

  // ── Palmarès ───────────────────────────────────────────

  Future<List<AchievementModel>> getAchievements(String userId) async {
    final data = await _client
        .from('achievements')
        .select()
        .eq('profile_id', userId)
        .order('year', ascending: false);
    return (data as List)
        .map((e) => AchievementModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addAchievement(Map<String, dynamic> data) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Non connecté');
    data['profile_id'] = user.id;
    await _client.from('achievements').insert(data);
  }

  Future<void> deleteAchievement(String id) async {
    await _client.from('achievements').delete().eq('id', id);
  }

  // ── Publications ───────────────────────────────────────

  Future<List<PostModel>> getProfilePosts(String userId) async {
    final currentUser = _client.auth.currentUser;
    final isOwn = currentUser != null && currentUser.id == userId;

    // Le propriétaire voit aussi ses posts en attente de modération,
    // sinon il a l'impression que rien n'a été enregistré.
    final statuses = isOwn
        ? ['published', 'pending_moderation']
        : ['published'];

    final data = await _client
        .from('posts')
        .select()
        .eq('author_id', userId)
        .inFilter('status', statuses)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Followers ──────────────────────────────────────────

  Future<int> getFollowersCount(String userId) async {
    final res = await _client
        .from('follows')
        .select('id')
        .eq('following_id', userId);
    return (res as List).length;
  }

  Future<int> getFollowingCount(String userId) async {
    final res = await _client
        .from('follows')
        .select('id')
        .eq('follower_id', userId);
    return (res as List).length;
  }

  Future<bool> isFollowing(String targetId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final res = await _client
        .from('follows')
        .select('id')
        .eq('follower_id', user.id)
        .eq('following_id', targetId)
        .maybeSingle();
    return res != null;
  }

  Future<void> toggleFollow(String targetId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Non connecté');
    final isFollowing = await this.isFollowing(targetId);
    if (isFollowing) {
      await _client.from('follows')
          .delete()
          .eq('follower_id', user.id)
          .eq('following_id', targetId);
    } else {
      await _client.from('follows').insert({
        'follower_id': user.id,
        'following_id': targetId,
      });
    }
  }

  // ── Sports & Positions ─────────────────────────────────

  Future<List<Map<String, dynamic>>> getSports() async {
    final data = await _client
        .from('sports')
        .select('id, name_fr, slug')
        .eq('is_active', true)
        .order('name_fr');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getPositions(int sportId) async {
    final data = await _client
        .from('positions')
        .select('id, name_fr, slug')
        .eq('sport_id', sportId)
        .order('name_fr');
    return (data as List).cast<Map<String, dynamic>>();
  }

  // ── Incrément vues ─────────────────────────────────────

  Future<void> incrementProfileViews(String userId) async {
    await _client.rpc('increment_profile_views', params: {'p_profile_id': userId});
  }
}
