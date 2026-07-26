-- ============================================================
-- DeNoTa CI — Migration 003 : Row Level Security (RLS)
-- ============================================================
-- Règle d'or : chaque utilisateur ne voit et modifie
-- que ce qu'il a le droit de voir/modifier.
-- ============================================================

-- ── Activer RLS sur toutes les tables ──────────────────────
ALTER TABLE profiles           ENABLE ROW LEVEL SECURITY;
ALTER TABLE athlete_profiles   ENABLE ROW LEVEL SECURITY;
ALTER TABLE institutions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE recruiter_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE athlete_institutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievements       ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts              ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes         ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_comments      ENABLE ROW LEVEL SECURITY;
ALTER TABLE athlete_stats      ENABLE ROW LEVEL SECURITY;
ALTER TABLE expert_ratings     ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations      ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages           ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications      ENABLE ROW LEVEL SECURITY;
ALTER TABLE follows            ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites          ENABLE ROW LEVEL SECURITY;
ALTER TABLE challenges         ENABLE ROW LEVEL SECURITY;
ALTER TABLE challenge_entries  ENABLE ROW LEVEL SECURITY;
ALTER TABLE events             ENABLE ROW LEVEL SECURITY;

-- ── Helper : est-ce un admin ? ─────────────────────────────
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- ── Helper : est-ce un expert ? ───────────────────────────
CREATE OR REPLACE FUNCTION is_expert()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'expert'
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- ── Helper : abonnement premium sportif ? ─────────────────
CREATE OR REPLACE FUNCTION is_premium_athlete()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
      AND role = 'athlete'
      AND subscription_plan = 'athlete_premium'
      AND (subscription_expires_at IS NULL OR subscription_expires_at > NOW())
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- ── Helper : est recruteur pro ? ──────────────────────────
CREATE OR REPLACE FUNCTION is_recruiter_pro()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
      AND role IN ('recruiter', 'sponsor')
      AND subscription_plan IN ('recruiter_pro', 'sponsor_access')
      AND (subscription_expires_at IS NULL OR subscription_expires_at > NOW())
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- ============================================================
-- POLICIES : profiles
-- ============================================================

-- Tout le monde peut voir les profils actifs et cherchables
CREATE POLICY "profiles_public_read" ON profiles
  FOR SELECT USING (
    status = 'active'
    AND is_searchable = TRUE
    -- Les mineurs ne sont visibles que par les recruteurs pro et admins
    AND (
      is_minor = FALSE
      OR is_admin()
      OR is_recruiter_pro()
      OR auth.uid() = id
    )
  );

-- Chacun peut voir son propre profil
CREATE POLICY "profiles_self_read" ON profiles
  FOR SELECT USING (auth.uid() = id);

-- Chacun peut modifier son propre profil
CREATE POLICY "profiles_self_update" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Insertion lors de l'inscription (via trigger)
CREATE POLICY "profiles_insert_own" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Admin : accès total
CREATE POLICY "profiles_admin_all" ON profiles
  FOR ALL USING (is_admin());

-- ============================================================
-- POLICIES : athlete_profiles
-- ============================================================
CREATE POLICY "athlete_profiles_public_read" ON athlete_profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = athlete_profiles.profile_id
        AND p.status = 'active'
        AND p.is_searchable = TRUE
    )
  );

CREATE POLICY "athlete_profiles_self_write" ON athlete_profiles
  FOR ALL USING (auth.uid() = profile_id);

CREATE POLICY "athlete_profiles_admin" ON athlete_profiles
  FOR ALL USING (is_admin());

-- ============================================================
-- POLICIES : posts
-- ============================================================
CREATE POLICY "posts_public_read" ON posts
  FOR SELECT USING (
    status = 'published'
    AND is_public = TRUE
  );

CREATE POLICY "posts_self_read" ON posts
  FOR SELECT USING (auth.uid() = author_id);

CREATE POLICY "posts_self_write" ON posts
  FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY "posts_self_update" ON posts
  FOR UPDATE USING (
    auth.uid() = author_id
    AND status IN ('draft', 'rejected')
  );

CREATE POLICY "posts_admin_all" ON posts
  FOR ALL USING (is_admin());

-- ============================================================
-- POLICIES : expert_ratings
-- ============================================================

-- Les notations publiques sont visibles de tous
CREATE POLICY "ratings_public_read" ON expert_ratings
  FOR SELECT USING (is_public = TRUE);

-- L'athlète voit toutes ses notations (même privées)
CREATE POLICY "ratings_athlete_read" ON expert_ratings
  FOR SELECT USING (auth.uid() = athlete_id);

-- Seuls les experts peuvent noter
CREATE POLICY "ratings_expert_insert" ON expert_ratings
  FOR INSERT WITH CHECK (
    auth.uid() = expert_id
    AND is_expert()
  );

-- L'expert peut modifier sa propre notation (dans les 7 jours)
CREATE POLICY "ratings_expert_update" ON expert_ratings
  FOR UPDATE USING (
    auth.uid() = expert_id
    AND is_expert()
    AND created_at > NOW() - INTERVAL '7 days'
  );

CREATE POLICY "ratings_admin" ON expert_ratings
  FOR ALL USING (is_admin());

-- ============================================================
-- POLICIES : conversations & messages
-- ============================================================

-- Une conversation n'est visible que par ses participants
CREATE POLICY "conversations_participants" ON conversations
  FOR SELECT USING (
    auth.uid() = participant_1
    OR auth.uid() = participant_2
  );

-- Créer une conversation : le créateur doit être Premium ou recruteur
CREATE POLICY "conversations_create" ON conversations
  FOR INSERT WITH CHECK (
    auth.uid() = participant_1
    AND (is_premium_athlete() OR is_recruiter_pro() OR is_admin())
  );

-- Messages : visibles uniquement par les participants
CREATE POLICY "messages_read" ON messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = messages.conversation_id
        AND (c.participant_1 = auth.uid() OR c.participant_2 = auth.uid())
    )
  );

-- Envoyer un message : être participant de la conversation
CREATE POLICY "messages_send" ON messages
  FOR INSERT WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = messages.conversation_id
        AND (c.participant_1 = auth.uid() OR c.participant_2 = auth.uid())
    )
  );

-- ============================================================
-- POLICIES : notifications
-- ============================================================
CREATE POLICY "notifications_own" ON notifications
  FOR ALL USING (auth.uid() = recipient_id);

-- ============================================================
-- POLICIES : favorites (recruteurs seulement)
-- ============================================================
CREATE POLICY "favorites_own" ON favorites
  FOR ALL USING (
    auth.uid() = recruiter_id
    AND is_recruiter_pro()
  );

-- ============================================================
-- POLICIES : follows
-- ============================================================
CREATE POLICY "follows_read_all" ON follows
  FOR SELECT USING (TRUE);

CREATE POLICY "follows_own_write" ON follows
  FOR INSERT WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "follows_own_delete" ON follows
  FOR DELETE USING (auth.uid() = follower_id);

-- ============================================================
-- POLICIES : athlete_stats
-- ============================================================
CREATE POLICY "stats_public_read" ON athlete_stats
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = athlete_stats.athlete_id AND p.status = 'active'
    )
  );

CREATE POLICY "stats_self_write" ON athlete_stats
  FOR ALL USING (auth.uid() = athlete_id);

CREATE POLICY "stats_admin" ON athlete_stats
  FOR ALL USING (is_admin());

-- ============================================================
-- POLICIES : tables publiques (lecture libre)
-- ============================================================
CREATE POLICY "sports_public" ON sports FOR SELECT USING (is_active = TRUE);
CREATE POLICY "positions_public" ON positions FOR SELECT USING (TRUE);
CREATE POLICY "challenges_public" ON challenges FOR SELECT USING (is_active = TRUE);
CREATE POLICY "events_public" ON events FOR SELECT USING (is_published = TRUE);
CREATE POLICY "achievements_public" ON achievements FOR SELECT USING (TRUE);
CREATE POLICY "post_likes_public" ON post_likes FOR SELECT USING (TRUE);
CREATE POLICY "post_comments_public" ON post_comments FOR SELECT USING (TRUE);
CREATE POLICY "challenge_entries_public" ON challenge_entries FOR SELECT USING (TRUE);

-- Écriture
CREATE POLICY "post_likes_own" ON post_likes FOR INSERT WITH CHECK (auth.uid() = profile_id);
CREATE POLICY "post_likes_delete" ON post_likes FOR DELETE USING (auth.uid() = profile_id);
CREATE POLICY "post_comments_own_write" ON post_comments FOR INSERT WITH CHECK (auth.uid() = author_id);
CREATE POLICY "challenge_entries_own" ON challenge_entries FOR INSERT WITH CHECK (auth.uid() = athlete_id);
CREATE POLICY "achievements_own" ON achievements FOR ALL USING (auth.uid() = profile_id);
