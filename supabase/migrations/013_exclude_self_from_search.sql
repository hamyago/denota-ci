-- ============================================================
-- Migration 013 — Ne pas s'afficher soi-même dans les talents
-- ============================================================
-- Ajoute un filtre AND (auth.uid() IS NULL OR p.id <> auth.uid())
-- à la fonction search_athletes.

CREATE OR REPLACE FUNCTION public.search_athletes(
  p_sport_id integer DEFAULT NULL,
  p_position_id integer DEFAULT NULL,
  p_level text DEFAULT NULL,
  p_city text DEFAULT NULL,
  p_country text DEFAULT NULL,
  p_age_min integer DEFAULT NULL,
  p_age_max integer DEFAULT NULL,
  p_score_min numeric DEFAULT NULL,
  p_availability text DEFAULT NULL,
  p_limit integer DEFAULT 20,
  p_offset integer DEFAULT 0)
RETURNS TABLE(id uuid, full_name text, username text, avatar_url text, city text, country text, sport_name text, position_name text, level text, talent_score numeric, followers_count bigint, posts_count bigint, kyc_level kyc_level, is_minor boolean)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
    AND (a.is_minor = FALSE OR is_admin() OR is_recruiter_pro())
    -- Exclure l'utilisateur courant
    AND (auth.uid() IS NULL OR p.id <> auth.uid())
  ORDER BY a.talent_score DESC NULLS LAST
  LIMIT p_limit OFFSET p_offset;
END;
$function$;
