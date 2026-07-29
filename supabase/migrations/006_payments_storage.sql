-- ============================================================
-- DeNoTa CI — Migration 006 : Paiements & policies storage upsert
-- À exécuter dans le SQL Editor de Supabase (denota-ci)
-- ============================================================

-- Table des tentatives de paiement (référencée par PaymentService)
-- Sans elle, TOUT paiement échoue dès la première requête.
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

CREATE INDEX IF NOT EXISTS idx_payment_attempts_user ON payment_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_attempts_status ON payment_attempts(status);

ALTER TABLE payment_attempts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "payment_own_select" ON payment_attempts
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "payment_own_insert" ON payment_attempts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "payment_admin_all" ON payment_attempts
  FOR ALL USING (is_admin());

CREATE TRIGGER trg_payment_attempts_updated
  BEFORE UPDATE ON payment_attempts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- Policies UPDATE manquantes pour l'upsert Storage
-- (ré-upload avatar/bannière : upsert = INSERT + UPDATE,
--  or seul 'avatars' avait une policy UPDATE)
-- ============================================================

CREATE POLICY "banners_posts_owner_update" ON storage.objects
  FOR UPDATE USING (
    bucket_id IN ('posts','banners','institutions')
    AND auth.uid()::TEXT = (storage.foldername(name))[1]
  );

CREATE POLICY "videos_owner_update" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'videos'
    AND auth.uid()::TEXT = (storage.foldername(name))[1]
  );

CREATE POLICY "banners_posts_owner_delete" ON storage.objects
  FOR DELETE USING (
    bucket_id IN ('posts','banners','institutions')
    AND auth.uid()::TEXT = (storage.foldername(name))[1]
  );
