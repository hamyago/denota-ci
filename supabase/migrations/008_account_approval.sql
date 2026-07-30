-- ============================================================
-- DeNoTa CI — Migration 008 : Validation des comptes par l'admin
-- ------------------------------------------------------------
-- Certains rôles (recruteur, institution, expert) doivent être
-- VALIDÉS par un admin avant d'accéder à la plateforme. Ils sont
-- créés en statut 'pending' ; l'admin les passe en 'active'
-- (approuvé) ou 'banned' (refusé). Les athlètes et sponsors
-- restent actifs immédiatement (auto-inscription).
--
-- Pour exiger aussi la validation des athlètes : ajouter 'athlete'
-- à la liste v_roles_pending ci-dessous.
-- Idempotente (relançable sans erreur).
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_username        TEXT;
  v_base            TEXT;
  v_role            user_role;
  v_status          account_status;
  v_roles_pending   user_role[] := ARRAY['recruiter','institution','expert']::user_role[];
BEGIN
  -- Rôle demandé (défaut athlète)
  v_role := COALESCE(NEW.raw_user_meta_data->>'role', 'athlete')::user_role;

  -- Statut initial : 'pending' si le rôle exige une validation admin,
  -- 'active' sinon.
  IF v_role = ANY (v_roles_pending) THEN
    v_status := 'pending'::account_status;
  ELSE
    v_status := 'active'::account_status;
  END IF;

  -- Username unique
  v_base := COALESCE(
    NEW.raw_user_meta_data->>'username',
    split_part(NEW.email, '@', 1)
  );
  v_username := public.generate_unique_username(v_base);

  INSERT INTO public.profiles (id, email, full_name, username, role, status)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Utilisateur'),
    v_username,
    v_role,
    v_status
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'handle_new_user FAILED for % : % (%)', NEW.email, SQLERRM, SQLSTATE;
  RETURN NEW;
END;
$$;

-- ── Fonctions d'administration (approuver / refuser) ─────────
-- SECURITY DEFINER + garde is_admin() : seul un admin peut agir.

CREATE OR REPLACE FUNCTION public.admin_approve_user(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Seul un administrateur peut valider un compte';
  END IF;
  UPDATE public.profiles SET status = 'active' WHERE id = p_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_reject_user(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Seul un administrateur peut refuser un compte';
  END IF;
  UPDATE public.profiles SET status = 'banned' WHERE id = p_user_id;
END;
$$;
