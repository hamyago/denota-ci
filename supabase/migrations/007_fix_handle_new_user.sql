-- ============================================================
-- DeNoTa CI — Migration 007
-- Corrige handle_new_user : username unique garanti + rattrapage
-- des profils manquants. Idempotente (relançable sans erreur).
-- ============================================================

-- ── 1. Fonction utilitaire : génère un username unique ──────
-- Part d'une base (username fourni, sinon partie locale de l'email,
-- sinon 'user'), nettoie les caractères invalides, puis ajoute un
-- suffixe numérique tant que le username est déjà pris.
CREATE OR REPLACE FUNCTION public.generate_unique_username(p_base TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  v_base      TEXT;
  v_candidate TEXT;
  v_suffix    INT := 0;
BEGIN
  -- Nettoyage : lower() AVANT le regexp (sinon les majuscules sautent),
  -- puis on ne garde que [a-z0-9_].
  v_base := regexp_replace(
              lower(COALESCE(NULLIF(trim(p_base), ''), 'user')),
              '[^a-z0-9_]', '', 'g');
  IF v_base = '' THEN
    v_base := 'user';
  END IF;
  -- Limite de longueur raisonnable
  v_base := left(v_base, 20);

  v_candidate := v_base;
  WHILE EXISTS (SELECT 1 FROM public.profiles WHERE username = v_candidate) LOOP
    v_suffix := v_suffix + 1;
    v_candidate := v_base || v_suffix::TEXT;
  END LOOP;

  RETURN v_candidate;
END;
$$;

-- ── 2. Recrée handle_new_user avec username unique ──────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_username TEXT;
  v_base     TEXT;
BEGIN
  -- Base du username : celui fourni, sinon la partie locale de l'email
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
    COALESCE(NEW.raw_user_meta_data->>'role', 'athlete')::user_role,
    'active'::account_status
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- On loggue mais on ne bloque JAMAIS la création du compte auth.
  RAISE LOG 'handle_new_user FAILED for % : % (%)', NEW.email, SQLERRM, SQLSTATE;
  RETURN NEW;
END;
$$;

-- Le trigger on_auth_user_created pointe déjà sur cette fonction :
-- pas besoin de le recréer.

-- ── 3. Rattrapage : crée les profils manquants ──────────────
-- Tout utilisateur auth sans profil récupère un profil actif.
INSERT INTO public.profiles (id, email, full_name, username, role, status)
SELECT
  u.id,
  u.email,
  COALESCE(u.raw_user_meta_data->>'full_name', 'Utilisateur'),
  public.generate_unique_username(
    COALESCE(u.raw_user_meta_data->>'username', split_part(u.email, '@', 1))
  ),
  COALESCE(u.raw_user_meta_data->>'role', 'athlete')::user_role,
  'active'::account_status
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
WHERE p.id IS NULL;
