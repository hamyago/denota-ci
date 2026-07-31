-- ============================================================
-- DeNoTa CI — Migration 009 : Durcissement sécurité
-- ------------------------------------------------------------
-- CORRIGE UN BUG CRITIQUE : is_admin() (et les autres fonctions)
-- n'avaient pas de search_path fixe. Selon le contexte d'appel
-- (ex. PostgREST avec search_path vide), `SELECT ... FROM profiles`
-- échouait car `profiles` n'était pas résolu → is_admin() plantait
-- → la policy posts_admin_all ne s'appliquait pas → l'admin ne
-- voyait AUCUN post en attente de modération.
--
-- Corrige aussi les ~60 warnings "Function Search Path Mutable"
-- et les alertes du Security Advisor. Idempotente.
-- ============================================================

-- ── 1. Fixe search_path = public sur toutes les fonctions applicatives ──
ALTER FUNCTION public.is_admin()                       SET search_path = public;
ALTER FUNCTION public.is_expert()                      SET search_path = public;
ALTER FUNCTION public.is_premium_athlete()             SET search_path = public;
ALTER FUNCTION public.is_recruiter_pro()               SET search_path = public;
ALTER FUNCTION public.generate_unique_username(text)   SET search_path = public;
ALTER FUNCTION public.handle_new_user()                SET search_path = public;
ALTER FUNCTION public.admin_approve_user(uuid)         SET search_path = public;
ALTER FUNCTION public.admin_reject_user(uuid)          SET search_path = public;
ALTER FUNCTION public.calculate_talent_score(uuid)     SET search_path = public;
ALTER FUNCTION public.calculate_profile_score(uuid)    SET search_path = public;
ALTER FUNCTION public.increment_post_views(uuid)       SET search_path = public;
ALTER FUNCTION public.increment_profile_views(uuid)    SET search_path = public;
ALTER FUNCTION public.decrement_on_unlike()            SET search_path = public;
ALTER FUNCTION public.notify_on_like()                 SET search_path = public;
ALTER FUNCTION public.notify_on_contact_request()      SET search_path = public;
ALTER FUNCTION public.update_conversation_last_message() SET search_path = public;
ALTER FUNCTION public.update_updated_at()              SET search_path = public;
ALTER FUNCTION public.trigger_recalculate_talent_score() SET search_path = public;
ALTER FUNCTION public.search_athletes(integer,integer,text,text,text,integer,integer,numeric,text,integer,integer) SET search_path = public;

-- ── 2. Vue athletes_search : respecter la RLS de l'appelant ──
ALTER VIEW public.athletes_search SET (security_invoker = true);

-- ── 3. Tables avec RLS activée mais sans policy ──
-- Données de référence publiques (lecture pour tous)
DROP POLICY IF EXISTS "cities_public_read" ON public.cities;
CREATE POLICY "cities_public_read" ON public.cities FOR SELECT USING (true);

DROP POLICY IF EXISTS "countries_public_read" ON public.countries;
CREATE POLICY "countries_public_read" ON public.countries FOR SELECT USING (true);

DROP POLICY IF EXISTS "institutions_public_read" ON public.institutions;
CREATE POLICY "institutions_public_read" ON public.institutions FOR SELECT USING (true);

-- Appartenance athlète↔club : lecture publique, écriture par l'athlète
DROP POLICY IF EXISTS "athlete_inst_public_read" ON public.athlete_institutions;
CREATE POLICY "athlete_inst_public_read" ON public.athlete_institutions
  FOR SELECT USING (true);
DROP POLICY IF EXISTS "athlete_inst_owner_write" ON public.athlete_institutions;
CREATE POLICY "athlete_inst_owner_write" ON public.athlete_institutions
  FOR ALL USING (auth.uid() = athlete_id) WITH CHECK (auth.uid() = athlete_id);

-- Profil recruteur : lecture publique, écriture par le propriétaire
DROP POLICY IF EXISTS "recruiter_prof_public_read" ON public.recruiter_profiles;
CREATE POLICY "recruiter_prof_public_read" ON public.recruiter_profiles
  FOR SELECT USING (true);
DROP POLICY IF EXISTS "recruiter_prof_owner_write" ON public.recruiter_profiles;
CREATE POLICY "recruiter_prof_owner_write" ON public.recruiter_profiles
  FOR ALL USING (auth.uid() = profile_id) WITH CHECK (auth.uid() = profile_id);

-- Note : public.spatial_ref_sys (table système PostGIS) est laissée telle
-- quelle. Activer la RLS dessus peut casser les requêtes spatiales ; elle ne
-- contient que des données de référence de projections, sans info sensible.

-- ── 4. Restreindre l'exécution des fonctions admin ──
-- Par défaut, une fonction est exécutable par PUBLIC (dont anon). Même si
-- admin_approve_user/reject vérifient is_admin(), on retire l'accès public.
REVOKE EXECUTE ON FUNCTION public.admin_approve_user(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_reject_user(uuid)  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.admin_approve_user(uuid) TO authenticated;
GRANT  EXECUTE ON FUNCTION public.admin_reject_user(uuid)  TO authenticated;
