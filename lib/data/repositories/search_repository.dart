// lib/data/repositories/search_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SearchFilters {
  final int? sportId;
  final int? positionId;
  final String? level;       // amateur | semi_pro | professional
  final String? city;
  final String? country;
  final int? ageMin;
  final int? ageMax;
  final double? scoreMin;
  final String? availability;
  final String? gender;
  final String? kycLevel;
  final String sortBy;       // talent_score | followers | recent
  final int limit;
  final int offset;

  const SearchFilters({
    this.sportId,
    this.positionId,
    this.level,
    this.city,
    this.country,
    this.ageMin,
    this.ageMax,
    this.scoreMin,
    this.availability,
    this.gender,
    this.kycLevel,
    this.sortBy = 'talent_score',
    this.limit  = 20,
    this.offset = 0,
  });

  bool get hasActiveFilters =>
      sportId != null || positionId != null || level != null ||
      city != null || country != null || ageMin != null || ageMax != null ||
      scoreMin != null || availability != null || gender != null;

  int get activeCount {
    int n = 0;
    if (sportId != null)     n++;
    if (positionId != null)  n++;
    if (level != null)       n++;
    if (city != null)        n++;
    if (country != null)     n++;
    if (ageMin != null || ageMax != null) n++;
    if (scoreMin != null)    n++;
    if (availability != null) n++;
    return n;
  }

  SearchFilters copyWith({
    int? sportId, int? positionId, String? level,
    String? city, String? country, int? ageMin, int? ageMax,
    double? scoreMin, String? availability, String? gender,
    String? kycLevel, String? sortBy, int? limit, int? offset,
    bool clearSport = false, bool clearPosition = false,
    bool clearLevel = false, bool clearCity = false,
    bool clearAvailability = false, bool clearScore = false,
    bool clearAge = false,
  }) => SearchFilters(
    sportId:      clearSport       ? null : sportId      ?? this.sportId,
    positionId:   clearPosition    ? null : positionId   ?? this.positionId,
    level:        clearLevel       ? null : level        ?? this.level,
    city:         clearCity        ? null : city         ?? this.city,
    country:      country          ?? this.country,
    ageMin:       clearAge         ? null : ageMin       ?? this.ageMin,
    ageMax:       clearAge         ? null : ageMax       ?? this.ageMax,
    scoreMin:     clearScore       ? null : scoreMin     ?? this.scoreMin,
    availability: clearAvailability? null : availability ?? this.availability,
    gender:       gender           ?? this.gender,
    kycLevel:     kycLevel         ?? this.kycLevel,
    sortBy:       sortBy           ?? this.sortBy,
    limit:        limit            ?? this.limit,
    offset:       offset           ?? this.offset,
  );

  SearchFilters reset() => const SearchFilters();
}

class SearchRepository {
  final _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> searchAthletes(SearchFilters f) async {
    final data = await _client.rpc('search_athletes', params: {
      'p_sport_id':     f.sportId,
      'p_position_id':  f.positionId,
      'p_level':        f.level,
      'p_city':         f.city,
      'p_country':      f.country,
      'p_age_min':      f.ageMin,
      'p_age_max':      f.ageMax,
      'p_score_min':    f.scoreMin,
      'p_availability': f.availability,
      'p_limit':        f.limit,
      'p_offset':       f.offset,
    });
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fullTextSearch(String query, {int limit = 20}) async {
    final data = await _client
        .from('profiles')
        .select('''
          id, full_name, username, avatar_url, city, country, kyc_level,
          athlete_profiles!athlete_profiles_profile_id_fkey(talent_score, level, sports(name_fr), positions(name_fr))
        ''')
        .or('full_name.ilike.%$query%,username.ilike.%$query%')
        .eq('role', 'athlete')
        .eq('status', 'active')
        .eq('is_searchable', true)
        .limit(limit);

    return (data as List).map((e) {
      final m  = Map<String, dynamic>.from(e as Map);
      final ap = (e['athlete_profiles'] as List?)?.firstOrNull as Map?;
      m['talent_score']  = ap?['talent_score'];
      m['level']         = ap?['level'];
      m['sport_name']    = ap?['sports']?['name_fr'];
      m['position_name'] = ap?['positions']?['name_fr'];
      return m;
    }).toList();
  }

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
        .select('id, name_fr')
        .eq('sport_id', sportId)
        .order('name_fr');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getCities() async {
    final data = await _client
        .from('cities')
        .select('name, is_major')
        .eq('country', 'CI')
        .order('is_major', ascending: false)
        .order('name');
    return (data as List).cast<Map<String, dynamic>>();
  }

  // Top 10 talents pour la carte
  Future<List<Map<String, dynamic>>> getAthletesForMap(SearchFilters f) async {
    final data = await _client.rpc('search_athletes', params: {
      'p_sport_id': f.sportId,
      'p_level':    f.level,
      'p_country':  f.country ?? 'CI',
      'p_limit':    50,
      'p_offset':   0,
    });
    return (data as List)
        .cast<Map<String, dynamic>>()
        .where((e) => e['city'] != null)
        .toList();
  }

  // Suggestions de recherche
  Future<List<String>> getSearchSuggestions(String query) async {
    if (query.length < 2) return [];
    final data = await _client
        .from('profiles')
        .select('full_name, username')
        .or('full_name.ilike.%$query%,username.ilike.%$query%')
        .eq('role', 'athlete')
        .eq('status', 'active')
        .limit(8);
    final results = <String>[];
    for (final e in (data as List)) {
      results.add(e['full_name'] as String);
    }
    return results.toSet().toList();
  }
}
