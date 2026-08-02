-- ============================================================
-- Migration 010 — Système de signalement des publications
-- ============================================================
-- Crée la table post_reports (un signalement par utilisateur et par
-- publication), un trigger qui incrémente flag_count / is_flagged sur
-- posts, et masque automatiquement (status='archived') une publication
-- dès qu'elle atteint le seuil de signalements.
-- ============================================================

-- Seuil de signalements avant masquage automatique
-- (modifiable ici sans toucher au reste)
--   >= 3 signalements -> la publication passe en 'archived'
--   (retirée du fil, en attente de décision admin)

CREATE TABLE IF NOT EXISTS post_reports (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id      UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  reporter_id  UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reason       TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Un même utilisateur ne peut signaler une publication qu'une fois
  CONSTRAINT post_reports_unique UNIQUE (post_id, reporter_id)
);

CREATE INDEX IF NOT EXISTS idx_post_reports_post ON post_reports(post_id);
CREATE INDEX IF NOT EXISTS idx_post_reports_reporter ON post_reports(reporter_id);

-- ── RLS ─────────────────────────────────────────────────────
ALTER TABLE post_reports ENABLE ROW LEVEL SECURITY;

-- Un utilisateur connecté peut signaler (insérer) en son propre nom
DROP POLICY IF EXISTS post_reports_insert_self ON post_reports;
CREATE POLICY post_reports_insert_self ON post_reports
  FOR INSERT TO authenticated
  WITH CHECK (reporter_id = auth.uid());

-- Un utilisateur peut voir ses propres signalements ; l'admin voit tout
DROP POLICY IF EXISTS post_reports_select ON post_reports;
CREATE POLICY post_reports_select ON post_reports
  FOR SELECT TO authenticated
  USING (reporter_id = auth.uid() OR is_admin());

-- L'admin peut supprimer un signalement (nettoyage)
DROP POLICY IF EXISTS post_reports_admin_delete ON post_reports;
CREATE POLICY post_reports_admin_delete ON post_reports
  FOR DELETE TO authenticated
  USING (is_admin());

-- ── Trigger : maj des compteurs sur posts ───────────────────
CREATE OR REPLACE FUNCTION handle_new_report()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  -- Nombre total de signalements distincts pour cette publication
  SELECT COUNT(*) INTO v_count
  FROM post_reports WHERE post_id = NEW.post_id;

  UPDATE posts
  SET is_flagged = TRUE,
      flag_count = v_count,
      -- Masquage automatique au-delà du seuil (retiré du fil public)
      status = CASE
                 WHEN v_count >= 3 AND status = 'published' THEN 'archived'::content_status
                 ELSE status
               END,
      updated_at = NOW()
  WHERE id = NEW.post_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_new_report ON post_reports;
CREATE TRIGGER trg_new_report
  AFTER INSERT ON post_reports
  FOR EACH ROW EXECUTE FUNCTION handle_new_report();
