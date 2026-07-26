// lib/data/repositories/recruiter_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class FavoriteModel {
  final String id;
  final String recruiterId;
  final String athleteId;
  final String? note;
  final String listName;
  final DateTime createdAt;

  // Données athlète joinées
  final String? athleteName;
  final String? athleteUsername;
  final String? athleteAvatarUrl;
  final String? athleteCity;
  final String? sportName;
  final String? positionName;
  final String? level;
  final double? talentScore;
  final String? kycLevel;
  final bool isMinor;

  const FavoriteModel({
    required this.id,
    required this.recruiterId,
    required this.athleteId,
    this.note,
    required this.listName,
    required this.createdAt,
    this.athleteName,
    this.athleteUsername,
    this.athleteAvatarUrl,
    this.athleteCity,
    this.sportName,
    this.positionName,
    this.level,
    this.talentScore,
    this.kycLevel,
    this.isMinor = false,
  });

  factory FavoriteModel.fromJson(Map<String, dynamic> j) => FavoriteModel(
    id:          j['id'] as String,
    recruiterId: j['recruiter_id'] as String,
    athleteId:   j['athlete_id'] as String,
    note:        j['note'] as String?,
    listName:    j['list_name'] as String? ?? 'default',
    createdAt:   DateTime.parse(j['created_at'] as String),
    athleteName:       j['athlete_name'] as String?,
    athleteUsername:   j['athlete_username'] as String?,
    athleteAvatarUrl:  j['athlete_avatar_url'] as String?,
    athleteCity:       j['athlete_city'] as String?,
    sportName:         j['sport_name'] as String?,
    positionName:      j['position_name'] as String?,
    level:             j['level'] as String?,
    talentScore:       (j['talent_score'] as num?)?.toDouble(),
    kycLevel:          j['kyc_level'] as String?,
    isMinor:           j['is_minor'] as bool? ?? false,
  );

  String get levelLabel {
    switch (level) {
      case 'amateur':      return 'Amateur';
      case 'semi_pro':     return 'Semi-Pro';
      case 'professional': return 'Pro';
      default:             return '';
    }
  }
}

class AlertModel {
  final String id;
  final String recruiterId;
  final String athleteId;
  final String alertType;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  // Données athlète
  final String? athleteName;
  final String? athleteAvatarUrl;
  final String? sportName;
  final double? talentScore;

  const AlertModel({
    required this.id,
    required this.recruiterId,
    required this.athleteId,
    required this.alertType,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.athleteName,
    this.athleteAvatarUrl,
    this.sportName,
    this.talentScore,
  });

  factory AlertModel.fromJson(Map<String, dynamic> j) => AlertModel(
    id:           j['id'] as String,
    recruiterId:  j['recipient_id'] as String,
    athleteId:    (j['data'] as Map<String, dynamic>?)?['athlete_id'] as String? ?? '',
    alertType:    j['type'] as String,
    title:        j['title'] as String,
    body:         j['body'] as String? ?? '',
    isRead:       j['is_read'] as bool? ?? false,
    createdAt:    DateTime.parse(j['created_at'] as String),
    athleteName:      j['athlete_name'] as String?,
    athleteAvatarUrl: j['athlete_avatar_url'] as String?,
    sportName:        j['sport_name'] as String?,
    talentScore:      (j['talent_score'] as num?)?.toDouble(),
  );
}

class RecruiterStatsModel {
  final int favoritesCount;
  final int contactsSent;
  final int recruitmentsCount;
  final int unreadAlerts;
  final int profileViewsThisMonth;

  const RecruiterStatsModel({
    required this.favoritesCount,
    required this.contactsSent,
    required this.recruitmentsCount,
    required this.unreadAlerts,
    required this.profileViewsThisMonth,
  });
}

// ── Repository ────────────────────────────────────────────
class RecruiterRepository {
  final _client = Supabase.instance.client;

  String get _uid => _client.auth.currentUser!.id;

  // ── Stats globales ─────────────────────────────────────
  Future<RecruiterStatsModel> getStats() async {
    final results = await Future.wait([
      _client.from('favorites').select('id').eq('recruiter_id', _uid),
      _client.from('conversations').select('id').eq('participant_1', _uid),
      _client.from('notifications').select('id')
          .eq('recipient_id', _uid).eq('is_read', false),
    ]);

    return RecruiterStatsModel(
      favoritesCount:       (results[0] as List).length,
      contactsSent:         (results[1] as List).length,
      recruitmentsCount:    0,
      unreadAlerts:         (results[2] as List).length,
      profileViewsThisMonth: 0,
    );
  }

  // ── Favoris ────────────────────────────────────────────
  Future<List<FavoriteModel>> getFavorites({String listName = 'all'}) async {
    var query = _client.from('favorites').select('''
      *,
      athlete:profiles!athlete_id(
        full_name, username, avatar_url, city, kyc_level, is_minor,
        athlete_profiles(
          talent_score, level,
          sports(name_fr),
          positions(name_fr)
        )
      )
    ''').eq('recruiter_id', _uid);

    if (listName != 'all') query = query.eq('list_name', listName);

    final data = await query.order('created_at', ascending: false);

    return (data as List).map((e) {
      final j = Map<String, dynamic>.from(e as Map);
      final athlete = e['athlete'] as Map?;
      final ap = (athlete?['athlete_profiles'] as List?)?.firstOrNull as Map?;
      final sport = ap?['sports'] as Map?;
      final pos   = ap?['positions'] as Map?;

      j['athlete_name']       = athlete?['full_name'];
      j['athlete_username']   = athlete?['username'];
      j['athlete_avatar_url'] = athlete?['avatar_url'];
      j['athlete_city']       = athlete?['city'];
      j['kyc_level']          = athlete?['kyc_level'];
      j['is_minor']           = athlete?['is_minor'] ?? false;
      j['talent_score']       = ap?['talent_score'];
      j['level']              = ap?['level'];
      j['sport_name']         = sport?['name_fr'];
      j['position_name']      = pos?['name_fr'];

      return FavoriteModel.fromJson(j);
    }).toList();
  }

  Future<List<String>> getFavoriteLists() async {
    final data = await _client
        .from('favorites')
        .select('list_name')
        .eq('recruiter_id', _uid);
    final all = (data as List).map((e) => e['list_name'] as String).toSet().toList();
    return ['all', ...all];
  }

  Future<bool> isFavorite(String athleteId) async {
    final res = await _client.from('favorites')
        .select('id')
        .eq('recruiter_id', _uid)
        .eq('athlete_id', athleteId)
        .maybeSingle();
    return res != null;
  }

  Future<void> addFavorite(String athleteId, {String? note, String listName = 'default'}) async {
    await _client.from('favorites').upsert({
      'recruiter_id': _uid,
      'athlete_id':   athleteId,
      'note':         note,
      'list_name':    listName,
    });
  }

  Future<void> removeFavorite(String athleteId) async {
    await _client.from('favorites')
        .delete()
        .eq('recruiter_id', _uid)
        .eq('athlete_id', athleteId);
  }

  Future<void> updateFavoriteNote(String favoriteId, String note) async {
    await _client.from('favorites').update({'note': note}).eq('id', favoriteId);
  }

  Future<void> moveFavorite(String favoriteId, String newList) async {
    await _client.from('favorites').update({'list_name': newList}).eq('id', favoriteId);
  }

  // ── Alertes / Notifications ────────────────────────────
  Future<List<AlertModel>> getAlerts() async {
    final data = await _client.from('notifications')
        .select()
        .eq('recipient_id', _uid)
        .order('created_at', ascending: false)
        .limit(50);
    return (data as List)
        .map((e) => AlertModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAlertRead(String alertId) async {
    await _client.from('notifications')
        .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
        .eq('id', alertId);
  }

  Future<void> markAllAlertsRead() async {
    await _client.from('notifications')
        .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
        .eq('recipient_id', _uid)
        .eq('is_read', false);
  }

  // ── Recherche athlètes ─────────────────────────────────
  Future<List<Map<String, dynamic>>> searchAthletes({
    int? sportId,
    int? positionId,
    String? level,
    String? city,
    String? country,
    int? ageMin,
    int? ageMax,
    double? scoreMin,
    String? availability,
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _client.rpc('search_athletes', params: {
      'p_sport_id':     sportId,
      'p_position_id':  positionId,
      'p_level':        level,
      'p_city':         city,
      'p_country':      country,
      'p_age_min':      ageMin,
      'p_age_max':      ageMax,
      'p_score_min':    scoreMin,
      'p_availability': availability,
      'p_limit':        limit,
      'p_offset':       offset,
    });
    return (data as List).cast<Map<String, dynamic>>();
  }

  // ── Conversations (demandes contact) ──────────────────
  Future<void> sendContactRequest({
    required String athleteId,
    required String subject,
    required String contactReason,
  }) async {
    await _client.from('conversations').upsert({
      'participant_1':   _uid,
      'participant_2':   athleteId,
      'subject':         subject,
      'contact_reason':  contactReason,
    });
  }

  // ── Top talents récents ─────────────────────────────────
  Future<List<Map<String, dynamic>>> getTopTalents({int limit = 10}) async {
    return searchAthletes(scoreMin: 30, limit: limit);
  }

  // ── Talents récemment actifs ───────────────────────────
  Future<List<Map<String, dynamic>>> getRecentlyActive({int limit = 8}) async {
    final data = await _client
        .from('athletes_search')
        .select()
        .order('talent_score', ascending: false)
        .limit(limit);
    return (data as List).cast<Map<String, dynamic>>();
  }
}
