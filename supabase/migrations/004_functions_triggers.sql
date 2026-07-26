-- ============================================================
-- DeNoTa CI — Migration 004 : Fonctions & Triggers métier
-- ============================================================

-- ============================================================
-- FONCTION : Calcul du Talent Score™
-- Score composite 0-100
-- ============================================================
CREATE OR REPLACE FUNCTION calculate_talent_score(p_athlete_id UUID)
RETURNS DECIMAL AS $$
DECLARE
  v_expert_score    DECIMAL := 0;
  v_stats_score     DECIMAL := 0;
  v_engagement_score DECIMAL := 0;
  v_profile_score   DECIMAL := 0;
  v_final_score     DECIMAL := 0;
  v_expert_count    INTEGER;
  v_post_count      INTEGER;
  v_follower_count  INTEGER;
BEGIN
  -- 1. Score experts (40% du total) — moyenne des notations
  SELECT
    COALESCE(AVG(global_score) * 10, 0), -- ramené sur 100
    COUNT(*)
  INTO v_expert_score, v_expert_count
  FROM expert_ratings
  WHERE athlete_id = p_athlete_id;

  -- 2. Score statistiques (30%) — basé sur les stats vérifiées
  SELECT
    LEAST(
      COALESCE(
        (SELECT COUNT(*) * 5 FROM athlete_stats
         WHERE athlete_id = p_athlete_id AND verified = TRUE),
        0
      ), 30
    )
  INTO v_stats_score;

  -- 3. Score engagement (20%) — publications + followers
  SELECT COUNT(*) INTO v_post_count
  FROM posts WHERE author_id = p_athlete_id AND status = 'published';

  SELECT COUNT(*) INTO v_follower_count
  FROM follows WHERE following_id = p_athlete_id;

  v_engagement_score := LEAST(
    (LEAST(v_post_count, 10) * 1.0) +
    (LEAST(v_follower_count, 100) * 0.1),
    20
  );

  -- 4. Score profil (10%) — complétude
  SELECT COALESCE(profile_score * 0.1, 0) INTO v_profile_score
  FROM profiles WHERE id = p_athlete_id;

  -- Score final
  v_final_score := ROUND(
    (v_expert_score * 0.40) +
    (v_stats_score  * 1.00) +
    (v_engagement_score) +
    (v_profile_score),
    2
  );

  -- Mise à jour du score dans athlete_profiles
  UPDATE athlete_profiles
  SET
    talent_score = LEAST(v_final_score, 100),
    talent_score_updated_at = NOW()
  WHERE profile_id = p_athlete_id;

  RETURN LEAST(v_final_score, 100);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- TRIGGER : Recalcul du Talent Score après notation expert
-- ============================================================
CREATE OR REPLACE FUNCTION trigger_recalculate_talent_score()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM calculate_talent_score(
    CASE TG_OP WHEN 'DELETE' THEN OLD.athlete_id ELSE NEW.athlete_id END
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_rating_score_update
  AFTER INSERT OR UPDATE OR DELETE ON expert_ratings
  FOR EACH ROW EXECUTE FUNCTION trigger_recalculate_talent_score();

-- ============================================================
-- FONCTION : Calcul du score de complétude du profil (0-100)
-- ============================================================
CREATE OR REPLACE FUNCTION calculate_profile_score(p_profile_id UUID)
RETURNS INTEGER AS $$
DECLARE
  v_score INTEGER := 0;
  v_profile profiles%ROWTYPE;
  v_athlete athlete_profiles%ROWTYPE;
BEGIN
  SELECT * INTO v_profile FROM profiles WHERE id = p_profile_id;
  SELECT * INTO v_athlete FROM athlete_profiles WHERE profile_id = p_profile_id;

  -- Profil de base (50 points)
  IF v_profile.avatar_url IS NOT NULL     THEN v_score := v_score + 10; END IF;
  IF v_profile.bio IS NOT NULL            THEN v_score := v_score + 10; END IF;
  IF v_profile.date_of_birth IS NOT NULL  THEN v_score := v_score + 5;  END IF;
  IF v_profile.city IS NOT NULL           THEN v_score := v_score + 5;  END IF;
  IF v_profile.phone IS NOT NULL          THEN v_score := v_score + 5;  END IF;
  IF v_profile.banner_url IS NOT NULL     THEN v_score := v_score + 5;  END IF;
  IF v_profile.kyc_level != 'none'        THEN v_score := v_score + 10; END IF;

  -- Profil sportif (50 points, si athlète)
  IF v_athlete.profile_id IS NOT NULL THEN
    IF v_athlete.primary_sport_id IS NOT NULL    THEN v_score := v_score + 10; END IF;
    IF v_athlete.primary_position_id IS NOT NULL THEN v_score := v_score + 5;  END IF;
    IF v_athlete.height_cm IS NOT NULL           THEN v_score := v_score + 5;  END IF;
    IF v_athlete.current_club IS NOT NULL        THEN v_score := v_score + 5;  END IF;
    IF v_athlete.level IS NOT NULL               THEN v_score := v_score + 5;  END IF;
    -- A publié au moins une vidéo
    IF EXISTS (
      SELECT 1 FROM posts
      WHERE author_id = p_profile_id
        AND content_type = 'video'
        AND status = 'published'
    ) THEN v_score := v_score + 15; END IF;
  END IF;

  -- Mise à jour
  UPDATE profiles SET profile_score = LEAST(v_score, 100) WHERE id = p_profile_id;
  RETURN LEAST(v_score, 100);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- TRIGGER : Création automatique de profil après inscription
-- ============================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, email, full_name, username, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Utilisateur'),
    COALESCE(
      NEW.raw_user_meta_data->>'username',
      'user_' || LEFT(NEW.id::TEXT, 8)
    ),
    COALESCE(NEW.raw_user_meta_data->>'role', 'athlete')::user_role
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- TRIGGER : Incrément views sur un post
-- ============================================================
CREATE OR REPLACE FUNCTION increment_post_views(p_post_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE posts SET views_count = views_count + 1 WHERE id = p_post_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- TRIGGER : Incrément views sur un profil
-- ============================================================
CREATE OR REPLACE FUNCTION increment_profile_views(p_profile_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE profiles SET profile_views = profile_views + 1 WHERE id = p_profile_id;
  -- Notification au propriétaire du profil
  INSERT INTO notifications (recipient_id, type, title, body)
  VALUES (p_profile_id, 'profile_view', 'Nouveau visiteur', 'Quelqu''un a consulté votre profil.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- TRIGGER : Notification sur nouveau like
-- ============================================================
CREATE OR REPLACE FUNCTION notify_on_like()
RETURNS TRIGGER AS $$
DECLARE v_author UUID; v_liker_name TEXT;
BEGIN
  SELECT author_id INTO v_author FROM posts WHERE id = NEW.post_id;
  SELECT full_name INTO v_liker_name FROM profiles WHERE id = NEW.profile_id;

  IF v_author != NEW.profile_id THEN
    INSERT INTO notifications (recipient_id, sender_id, type, title, body, data)
    VALUES (
      v_author, NEW.profile_id, 'profile_view',
      '❤️ Nouveau like',
      v_liker_name || ' a aimé votre publication.',
      jsonb_build_object('post_id', NEW.post_id)
    );
    UPDATE posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_post_like
  AFTER INSERT ON post_likes
  FOR EACH ROW EXECUTE FUNCTION notify_on_like();

-- Décrement sur unlike
CREATE OR REPLACE FUNCTION decrement_on_unlike()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE posts SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = OLD.post_id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_post_unlike
  AFTER DELETE ON post_likes
  FOR EACH ROW EXECUTE FUNCTION decrement_on_unlike();

-- ============================================================
-- TRIGGER : Notification sur demande de contact
-- ============================================================
CREATE OR REPLACE FUNCTION notify_on_contact_request()
RETURNS TRIGGER AS $$
DECLARE v_sender_name TEXT;
BEGIN
  SELECT full_name INTO v_sender_name FROM profiles WHERE id = NEW.participant_1;
  INSERT INTO notifications (recipient_id, sender_id, type, title, body, data)
  VALUES (
    NEW.participant_2, NEW.participant_1, 'contact_request',
    '📩 Nouvelle demande de contact',
    v_sender_name || ' souhaite vous contacter : ' || COALESCE(NEW.subject, ''),
    jsonb_build_object('conversation_id', NEW.id, 'reason', NEW.contact_reason)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_contact_request
  AFTER INSERT ON conversations
  FOR EACH ROW EXECUTE FUNCTION notify_on_contact_request();

-- ============================================================
-- VUE : athletes_search (recherche optimisée)
-- ============================================================
CREATE OR REPLACE VIEW athletes_search AS
SELECT
  p.id,
  p.full_name,
  p.username,
  p.avatar_url,
  p.city,
  p.country,
  p.profile_views,
  p.kyc_level,
  p.is_minor,
  ap.primary_sport_id,
  ap.primary_position_id,
  ap.level,
  ap.height_cm,
  ap.weight_kg,
  ap.talent_score,
  ap.availability,
  ap.current_club,
  s.name_fr AS sport_name,
  pos.name_fr AS position_name,
  (SELECT COUNT(*) FROM posts WHERE author_id = p.id AND status = 'published') AS posts_count,
  (SELECT COUNT(*) FROM follows WHERE following_id = p.id) AS followers_count,
  (SELECT COUNT(*) FROM expert_ratings WHERE athlete_id = p.id) AS ratings_count
FROM profiles p
LEFT JOIN athlete_profiles ap ON ap.profile_id = p.id
LEFT JOIN sports s ON s.id = ap.primary_sport_id
LEFT JOIN positions pos ON pos.id = ap.primary_position_id
WHERE p.role = 'athlete'
  AND p.status = 'active'
  AND p.is_searchable = TRUE;

-- ============================================================
-- FONCTION : Recherche d'athlètes avec filtres
-- ============================================================
CREATE OR REPLACE FUNCTION search_athletes(
  p_sport_id      INTEGER DEFAULT NULL,
  p_position_id   INTEGER DEFAULT NULL,
  p_level         TEXT DEFAULT NULL,
  p_city          TEXT DEFAULT NULL,
  p_country       TEXT DEFAULT NULL,
  p_age_min       INTEGER DEFAULT NULL,
  p_age_max       INTEGER DEFAULT NULL,
  p_score_min     DECIMAL DEFAULT NULL,
  p_availability  TEXT DEFAULT NULL,
  p_limit         INTEGER DEFAULT 20,
  p_offset        INTEGER DEFAULT 0
)
RETURNS TABLE (
  id UUID, full_name TEXT, username TEXT, avatar_url TEXT,
  city TEXT, country TEXT, sport_name TEXT, position_name TEXT,
  level TEXT, talent_score DECIMAL, followers_count BIGINT,
  posts_count BIGINT, kyc_level kyc_level, is_minor BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    a.id, a.full_name, a.username, a.avatar_url,
    a.city, a.country, a.sport_name, a.position_name,
    a.level, a.talent_score, a.followers_count,
    a.posts_count, a.kyc_level, a.is_minor
  FROM athletes_search a
  JOIN profiles p ON p.id = a.id
  WHERE
    (p_sport_id IS NULL     OR a.primary_sport_id = p_sport_id)
    AND (p_position_id IS NULL OR a.primary_position_id = p_position_id)
    AND (p_level IS NULL       OR a.level = p_level)
    AND (p_city IS NULL        OR a.city ILIKE '%' || p_city || '%')
    AND (p_country IS NULL     OR a.country = p_country)
    AND (p_score_min IS NULL   OR a.talent_score >= p_score_min)
    AND (p_availability IS NULL OR a.availability = p_availability)
    AND (p_age_min IS NULL     OR DATE_PART('year', AGE(p.date_of_birth)) >= p_age_min)
    AND (p_age_max IS NULL     OR DATE_PART('year', AGE(p.date_of_birth)) <= p_age_max)
    -- Mineurs masqués sauf recruteurs pro / admins
    AND (a.is_minor = FALSE OR is_admin() OR is_recruiter_pro())
  ORDER BY a.talent_score DESC NULLS LAST
  LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
