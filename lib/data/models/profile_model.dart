// lib/data/models/profile_model.dart

class ProfileModel {
  final String id;
  final String role;
  final String status;
  final String kycLevel;
  final String subscriptionPlan;
  final String fullName;
  final String username;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? bio;
  final DateTime? dateOfBirth;
  final String? gender;
  final String country;
  final String? region;
  final String? city;
  final bool isMinor;
  final bool isSearchable;
  final int profileViews;
  final int profileScore;
  final DateTime createdAt;

  const ProfileModel({
    required this.id,
    required this.role,
    required this.status,
    required this.kycLevel,
    required this.subscriptionPlan,
    required this.fullName,
    required this.username,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.bannerUrl,
    this.bio,
    this.dateOfBirth,
    this.gender,
    this.country = 'CI',
    this.region,
    this.city,
    this.isMinor = false,
    this.isSearchable = true,
    this.profileViews = 0,
    this.profileScore = 0,
    required this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
    id:               json['id'] as String,
    role:             json['role'] as String? ?? 'athlete',
    status:           json['status'] as String? ?? 'pending',
    kycLevel:         json['kyc_level'] as String? ?? 'none',
    subscriptionPlan: json['subscription_plan'] as String? ?? 'free',
    fullName:         json['full_name'] as String? ?? '',
    username:         json['username'] as String? ?? '',
    email:            json['email'] as String? ?? '',
    phone:            json['phone'] as String?,
    avatarUrl:        json['avatar_url'] as String?,
    bannerUrl:        json['banner_url'] as String?,
    bio:              json['bio'] as String?,
    dateOfBirth:      json['date_of_birth'] != null
        ? DateTime.tryParse(json['date_of_birth'] as String)
        : null,
    gender:           json['gender'] as String?,
    country:          json['country'] as String? ?? 'CI',
    region:           json['region'] as String?,
    city:             json['city'] as String?,
    isMinor:          json['is_minor'] as bool? ?? false,
    isSearchable:     json['is_searchable'] as bool? ?? true,
    profileViews:     json['profile_views'] as int? ?? 0,
    profileScore:     json['profile_score'] as int? ?? 0,
    createdAt:        DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'full_name':    fullName,
    'username':     username,
    'phone':        phone,
    'bio':          bio,
    'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
    'gender':       gender,
    'country':      country,
    'region':       region,
    'city':         city,
    'is_searchable': isSearchable,
  };

  int get age {
    if (dateOfBirth == null) return 0;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  bool get isPremium => subscriptionPlan == 'athlete_premium';
  bool get isVerified => kycLevel != 'none' && kycLevel != 'email';
}

// ── AthleteProfile Model ──────────────────────────────────
class AthleteProfileModel {
  final String id;
  final String profileId;
  final int? primarySportId;
  final String? primarySportName;
  final int? primaryPositionId;
  final String? primaryPositionName;
  final double? heightCm;
  final double? weightKg;
  final String? dominantFoot;
  final String? level;
  final int? yearsOfPractice;
  final String? availability;
  final String? currentClub;
  final String? currentInstitutionId;
  final double talentScore;
  final String? instagramUrl;
  final String? tiktokUrl;
  final String? youtubeUrl;
  final List<String> contractTypes;

  const AthleteProfileModel({
    required this.id,
    required this.profileId,
    this.primarySportId,
    this.primarySportName,
    this.primaryPositionId,
    this.primaryPositionName,
    this.heightCm,
    this.weightKg,
    this.dominantFoot,
    this.level,
    this.yearsOfPractice,
    this.availability,
    this.currentClub,
    this.currentInstitutionId,
    this.talentScore = 0,
    this.instagramUrl,
    this.tiktokUrl,
    this.youtubeUrl,
    this.contractTypes = const [],
  });

  factory AthleteProfileModel.fromJson(Map<String, dynamic> json) =>
      AthleteProfileModel(
        id:                  json['id'] as String,
        profileId:           json['profile_id'] as String,
        primarySportId:      json['primary_sport_id'] as int?,
        primarySportName:    json['sport_name'] as String?,
        primaryPositionId:   json['primary_position_id'] as int?,
        primaryPositionName: json['position_name'] as String?,
        heightCm:            (json['height_cm'] as num?)?.toDouble(),
        weightKg:            (json['weight_kg'] as num?)?.toDouble(),
        dominantFoot:        json['dominant_foot'] as String?,
        level:               json['level'] as String?,
        yearsOfPractice:     json['years_of_practice'] as int?,
        availability:        json['availability'] as String?,
        currentClub:         json['current_club'] as String?,
        currentInstitutionId: json['current_institution_id'] as String?,
        talentScore:         (json['talent_score'] as num?)?.toDouble() ?? 0,
        instagramUrl:        json['instagram_url'] as String?,
        tiktokUrl:           json['tiktok_url'] as String?,
        youtubeUrl:          json['youtube_url'] as String?,
        contractTypes:       (json['contract_types'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ?? [],
      );

  Map<String, dynamic> toJson() => {
    'primary_sport_id':    primarySportId,
    'primary_position_id': primaryPositionId,
    'height_cm':           heightCm,
    'weight_kg':           weightKg,
    'dominant_foot':       dominantFoot,
    'level':               level,
    'years_of_practice':   yearsOfPractice,
    'availability':        availability,
    'current_club':        currentClub,
    'instagram_url':       instagramUrl,
    'tiktok_url':          tiktokUrl,
    'youtube_url':         youtubeUrl,
    'contract_types':      contractTypes,
  };

  String get levelLabel {
    switch (level) {
      case 'amateur':      return 'Amateur';
      case 'semi_pro':     return 'Semi-Professionnel';
      case 'professional': return 'Professionnel';
      default:             return 'Non renseigné';
    }
  }

  String get availabilityLabel {
    switch (availability) {
      case 'immediate':    return 'Disponible immédiatement';
      case '3_months':     return 'Disponible dans 3 mois';
      case '6_months':     return 'Disponible dans 6 mois';
      case 'not_available': return 'Non disponible';
      default:             return 'À définir';
    }
  }

  String get dominantFootLabel {
    switch (dominantFoot) {
      case 'left':  return 'Pied gauche';
      case 'right': return 'Pied droit';
      case 'both':  return 'Les deux pieds';
      default:      return 'Non renseigné';
    }
  }
}

// ── AthleteStats Model ────────────────────────────────────
class AthleteStatsModel {
  final String id;
  final String athleteId;
  final int sportId;
  final String? season;
  final String? competition;
  final int matchesPlayed;
  final int minutesPlayed;
  final int wins;
  final int losses;
  final int draws;
  final Map<String, dynamic> sportStats;
  final double? aiSpeedKmh;
  final double? aiJumpCm;
  final int? aiReactionMs;
  final String source;
  final bool verified;

  const AthleteStatsModel({
    required this.id,
    required this.athleteId,
    required this.sportId,
    this.season,
    this.competition,
    this.matchesPlayed = 0,
    this.minutesPlayed = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.sportStats = const {},
    this.aiSpeedKmh,
    this.aiJumpCm,
    this.aiReactionMs,
    this.source = 'manual',
    this.verified = false,
  });

  factory AthleteStatsModel.fromJson(Map<String, dynamic> json) =>
      AthleteStatsModel(
        id:            json['id'] as String,
        athleteId:     json['athlete_id'] as String,
        sportId:       json['sport_id'] as int,
        season:        json['season'] as String?,
        competition:   json['competition'] as String?,
        matchesPlayed: json['matches_played'] as int? ?? 0,
        minutesPlayed: json['minutes_played'] as int? ?? 0,
        wins:          json['wins'] as int? ?? 0,
        losses:        json['losses'] as int? ?? 0,
        draws:         json['draws'] as int? ?? 0,
        sportStats:    (json['sport_stats'] as Map<String, dynamic>?) ?? {},
        aiSpeedKmh:    (json['ai_speed_kmh'] as num?)?.toDouble(),
        aiJumpCm:      (json['ai_jump_cm'] as num?)?.toDouble(),
        aiReactionMs:  json['ai_reaction_ms'] as int?,
        source:        json['source'] as String? ?? 'manual',
        verified:      json['verified'] as bool? ?? false,
      );
}

// ── ExpertRating Model ────────────────────────────────────
class ExpertRatingModel {
  final String id;
  final String expertId;
  final String? expertName;
  final String? expertAvatarUrl;
  final String athleteId;
  final double techniqueScore;
  final double physicalScore;
  final double mentalScore;
  final double statsScore;
  final double potentialScore;
  final double globalScore;
  final String? comment;
  final String? context;
  final bool isPublic;
  final DateTime createdAt;

  const ExpertRatingModel({
    required this.id,
    required this.expertId,
    this.expertName,
    this.expertAvatarUrl,
    required this.athleteId,
    required this.techniqueScore,
    required this.physicalScore,
    required this.mentalScore,
    required this.statsScore,
    required this.potentialScore,
    required this.globalScore,
    this.comment,
    this.context,
    this.isPublic = true,
    required this.createdAt,
  });

  factory ExpertRatingModel.fromJson(Map<String, dynamic> json) =>
      ExpertRatingModel(
        id:              json['id'] as String,
        expertId:        json['expert_id'] as String,
        expertName:      json['expert_name'] as String?,
        expertAvatarUrl: json['expert_avatar_url'] as String?,
        athleteId:       json['athlete_id'] as String,
        techniqueScore:  (json['technique_score'] as num).toDouble(),
        physicalScore:   (json['physical_score'] as num).toDouble(),
        mentalScore:     (json['mental_score'] as num).toDouble(),
        statsScore:      (json['stats_score'] as num).toDouble(),
        potentialScore:  (json['potential_score'] as num).toDouble(),
        globalScore:     (json['global_score'] as num).toDouble(),
        comment:         json['comment'] as String?,
        context:         json['context'] as String?,
        isPublic:        json['is_public'] as bool? ?? true,
        createdAt:       DateTime.parse(json['created_at'] as String),
      );
}

// ── Achievement Model ─────────────────────────────────────
class AchievementModel {
  final String id;
  final String profileId;
  final String title;
  final String? description;
  final int? year;
  final String? competition;
  final String? rank;
  final String? proofUrl;

  const AchievementModel({
    required this.id,
    required this.profileId,
    required this.title,
    this.description,
    this.year,
    this.competition,
    this.rank,
    this.proofUrl,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> json) =>
      AchievementModel(
        id:          json['id'] as String,
        profileId:   json['profile_id'] as String,
        title:       json['title'] as String,
        description: json['description'] as String?,
        year:        json['year'] as int?,
        competition: json['competition'] as String?,
        rank:        json['rank'] as String?,
        proofUrl:    json['proof_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'title':       title,
    'description': description,
    'year':        year,
    'competition': competition,
    'rank':        rank,
  };
}

// ── Post Model ────────────────────────────────────────────
class PostModel {
  final String id;
  final String authorId;
  final String contentType;
  final String status;
  final String? title;
  final String? body;
  final List<String> mediaUrls;
  final String? thumbnailUrl;
  final int? durationSec;
  final int viewsCount;
  final int likesCount;
  final int commentsCount;
  final DateTime? publishedAt;
  final DateTime createdAt;

  const PostModel({
    required this.id,
    required this.authorId,
    required this.contentType,
    required this.status,
    this.title,
    this.body,
    this.mediaUrls = const [],
    this.thumbnailUrl,
    this.durationSec,
    this.viewsCount = 0,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.publishedAt,
    required this.createdAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) => PostModel(
    id:           json['id'] as String,
    authorId:     json['author_id'] as String,
    contentType:  json['content_type'] as String,
    status:       json['status'] as String,
    title:        json['title'] as String?,
    body:         json['body'] as String?,
    mediaUrls:    (json['media_urls'] as List<dynamic>?)
        ?.map((e) => e as String).toList() ?? [],
    thumbnailUrl: json['thumbnail_url'] as String?,
    durationSec:  json['duration_sec'] as int?,
    viewsCount:   json['views_count'] as int? ?? 0,
    likesCount:   json['likes_count'] as int? ?? 0,
    commentsCount: json['comments_count'] as int? ?? 0,
    publishedAt:  json['published_at'] != null
        ? DateTime.tryParse(json['published_at'] as String) : null,
    createdAt:    DateTime.parse(json['created_at'] as String),
  );

  bool get isVideo => contentType == 'video';
  bool get isArticle => contentType == 'article';

  String get durationLabel {
    if (durationSec == null) return '';
    final m = durationSec! ~/ 60;
    final s = durationSec! % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
