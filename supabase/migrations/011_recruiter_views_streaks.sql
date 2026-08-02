-- ============================================================
-- Migration 011 — Vues recruteurs (badge + notif) & Streaks
-- ============================================================

-- ── FEATURE 6 : vues par recruteur ──────────────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS recruiter_view_count INTEGER DEFAULT 0;

-- ── FEATURE 1 : streaks d'entraînement ──────────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS current_streak INTEGER DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS longest_streak INTEGER DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_post_date DATE;

-- ── RPC vue de profil : notifie et distingue les recruteurs ──
CREATE OR REPLACE FUNCTION increment_profile_views(p_profile_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_viewer UUID := auth.uid();
  v_role   TEXT;
  v_name   TEXT;
  v_recent INTEGER;
BEGIN
  -- Compteur de vues global (comportement d'origine conservé)
  UPDATE profiles SET profile_views = COALESCE(profile_views, 0) + 1
  WHERE id = p_profile_id;

  -- Pas de notif si visiteur inconnu ou si on regarde son propre profil
  IF v_viewer IS NULL OR v_viewer = p_profile_id THEN
    RETURN;
  END IF;

  SELECT role, full_name INTO v_role, v_name FROM profiles WHERE id = v_viewer;

  -- Anti-spam : au plus une notif de ce visiteur sur ce profil par 24h
  SELECT count(*) INTO v_recent
  FROM notifications
  WHERE recipient_id = p_profile_id
    AND sender_id = v_viewer
    AND type = 'profile_view'
    AND created_at > NOW() - INTERVAL '24 hours';

  IF v_recent > 0 THEN
    RETURN;
  END IF;

  IF v_role = 'recruiter' THEN
    -- Vue précieuse : on incrémente le compteur dédié + notif spéciale
    UPDATE profiles
    SET recruiter_view_count = COALESCE(recruiter_view_count, 0) + 1
    WHERE id = p_profile_id;

    INSERT INTO notifications (recipient_id, sender_id, type, title, body, data)
    VALUES (
      p_profile_id, v_viewer, 'profile_view',
      '👀 Un recruteur a consulté ton profil',
      COALESCE(v_name, 'Un recruteur') || ' vient de regarder ton profil.',
      jsonb_build_object('viewer_role', 'recruiter', 'viewer_id', v_viewer)
    );
  ELSE
    INSERT INTO notifications (recipient_id, sender_id, type, title, body)
    VALUES (
      p_profile_id, v_viewer, 'profile_view',
      'Nouveau visiteur', 'Quelqu''un a consulté ton profil.'
    );
  END IF;
END;
$$;

-- ── Trigger de streak : à chaque nouvelle publication ───────
CREATE OR REPLACE FUNCTION handle_post_streak()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_last  DATE;
  v_cur   INTEGER;
  v_long  INTEGER;
  v_today DATE := (NOW() AT TIME ZONE 'UTC')::date;
BEGIN
  SELECT last_post_date, COALESCE(current_streak,0), COALESCE(longest_streak,0)
    INTO v_last, v_cur, v_long
  FROM profiles WHERE id = NEW.author_id;

  IF v_last = v_today THEN
    -- déjà posté aujourd'hui : streak inchangé
    RETURN NEW;
  ELSIF v_last = v_today - 1 THEN
    v_cur := v_cur + 1;          -- jour consécutif
  ELSE
    v_cur := 1;                  -- reprise (ou premier post)
  END IF;

  IF v_cur > v_long THEN
    v_long := v_cur;
  END IF;

  UPDATE profiles
  SET current_streak = v_cur,
      longest_streak = v_long,
      last_post_date = v_today
  WHERE id = NEW.author_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_post_streak ON posts;
CREATE TRIGGER trg_post_streak
  AFTER INSERT ON posts
  FOR EACH ROW EXECUTE FUNCTION handle_post_streak();
