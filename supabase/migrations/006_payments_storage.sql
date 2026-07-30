-- ============================================================
-- DeNoTa CI — Migration 006 : Paiements & policies storage upsert
-- Version IDEMPOTENTE : peut être relancée sans erreur.
-- À exécuter dans le SQL Editor de Supabase (denota-ci).
-- ============================================================

-- ── Table des tentatives de paiement (requise par PaymentService) ──
CREATE TABLE IF NOT EXISTS payment_attempts (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id        UUID REFERENCES profiles(id) ON DELETE CASCADE,
  plan           TEXT NOT NULL,
  amount_xof     INTEGER NOT NULL,
  method         TEXT NOT NULL,
  status         TEXT NOT NULL DEFAULT 'pending', -- pending | success | failed
  transaction_id TEXT,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payment_attempts_user   ON payment_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_attempts_status ON payment_attempts(status);

ALTER TABLE payment_attempts ENABLE ROW LEVEL SECURITY;

-- ── Policies paiement (drop puis recreate = idempotent) ──
DROP POLICY IF EXISTS "payment_own_select" ON payment_attempts;
CREATE POLICY "payment_own_select" ON payment_attempts
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "payment_own_insert" ON payment_attempts;
CREATE POLICY "payment_own_insert" ON payment_attempts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "payment_admin_all" ON payment_attempts;
CREATE POLICY "payment_admin_all" ON payment_attempts
  FOR ALL USING (is_admin());

-- ── Trigger updated_at (recreate propre) ──
DROP TRIGGER IF EXISTS trg_payment_attempts_updated ON payment_attempts;
CREATE TRIGGER trg_payment_attempts_updated
  BEFORE UPDATE ON payment_attempts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- Policies UPDATE/DELETE manquantes pour l'upsert Storage
-- (ré-upload avatar/bannière : upsert = INSERT + UPDATE)
-- ============================================================

DROP POLICY IF EXISTS "banners_posts_owner_update" ON storage.objects;
CREATE POLICY "banners_posts_owner_update" ON storage.objects
  FOR UPDATE USING (
    bucket_id IN ('posts','banners','institutions')
    AND auth.uid()::TEXT = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "videos_owner_update" ON storage.objects;
CREATE POLICY "videos_owner_update" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'videos'
    AND auth.uid()::TEXT = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "banners_posts_owner_delete" ON storage.objects;
CREATE POLICY "banners_posts_owner_delete" ON storage.objects
  FOR DELETE USING (
    bucket_id IN ('posts','banners','institutions')
    AND auth.uid()::TEXT = (storage.foldername(name))[1]
  );
