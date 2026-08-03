-- ============================================================
-- Migration 012 — Carte des talents (géolocalisation par ville)
-- ============================================================

-- Coordonnées ajoutées sur les profils (simples pour l'app Flutter)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS geo_lat DOUBLE PRECISION;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS geo_lng DOUBLE PRECISION;

-- Référentiel des principales villes de Côte d'Ivoire
CREATE TABLE IF NOT EXISTS ci_cities (
  name TEXT PRIMARY KEY,
  lat  DOUBLE PRECISION NOT NULL,
  lng  DOUBLE PRECISION NOT NULL
);

INSERT INTO ci_cities(name, lat, lng) VALUES
  ('Abidjan', 5.345, -4.024),
  ('Yamoussoukro', 6.827, -5.290),
  ('Bouaké', 7.690, -5.030),
  ('Daloa', 6.877, -6.450),
  ('San-Pédro', 4.748, -6.636),
  ('San Pedro', 4.748, -6.636),
  ('Korhogo', 9.458, -5.629),
  ('Man', 7.412, -7.554),
  ('Gagnoa', 6.131, -5.951),
  ('Divo', 5.839, -5.357),
  ('Abengourou', 6.729, -3.496),
  ('Anyama', 5.494, -4.052),
  ('Grand-Bassam', 5.211, -3.739),
  ('Séguéla', 7.961, -6.673),
  ('Odienné', 9.510, -7.564),
  ('Bondoukou', 8.040, -2.800),
  ('Soubré', 5.784, -6.593),
  ('Agboville', 5.928, -4.213),
  ('Dabou', 5.322, -4.377),
  ('Bingerville', 5.355, -3.887),
  ('Cocody', 5.359, -3.997),
  ('Yopougon', 5.345, -4.086)
ON CONFLICT (name) DO NOTHING;

-- Applique des coordonnées (ville + léger décalage) à un profil
CREATE OR REPLACE FUNCTION set_profile_geo_from_city()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_lat DOUBLE PRECISION;
  v_lng DOUBLE PRECISION;
BEGIN
  IF NEW.city IS NULL OR NEW.city = '' THEN
    RETURN NEW;
  END IF;

  SELECT lat, lng INTO v_lat, v_lng
  FROM ci_cities WHERE lower(name) = lower(NEW.city) LIMIT 1;

  -- Par défaut (ville inconnue) : Abidjan
  IF v_lat IS NULL THEN
    v_lat := 5.345; v_lng := -4.024;
  END IF;

  -- Décalage aléatoire (~±1.5 km) pour éviter la superposition
  NEW.geo_lat := v_lat + (random() - 0.5) * 0.03;
  NEW.geo_lng := v_lng + (random() - 0.5) * 0.03;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profile_geo ON profiles;
CREATE TRIGGER trg_profile_geo
  BEFORE INSERT OR UPDATE OF city ON profiles
  FOR EACH ROW EXECUTE FUNCTION set_profile_geo_from_city();

-- Backfill des profils existants qui ont une ville
UPDATE profiles p
SET geo_lat = c.lat + (random() - 0.5) * 0.03,
    geo_lng = c.lng + (random() - 0.5) * 0.03
FROM ci_cities c
WHERE lower(p.city) = lower(c.name) AND p.geo_lat IS NULL;

-- RPC : athlètes géolocalisés pour la carte
CREATE OR REPLACE FUNCTION athletes_on_map()
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  avatar_url TEXT,
  city TEXT,
  sport_name TEXT,
  talent_score INTEGER,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT
    p.id, p.full_name, p.avatar_url, p.city,
    s.name_fr AS sport_name,
    ap.talent_score,
    p.geo_lat, p.geo_lng
  FROM profiles p
  LEFT JOIN athlete_profiles ap ON ap.profile_id = p.id
  LEFT JOIN sports s ON s.id = ap.primary_sport_id
  WHERE p.role = 'athlete'
    AND p.geo_lat IS NOT NULL
    AND p.geo_lng IS NOT NULL;
$$;

GRANT EXECUTE ON FUNCTION athletes_on_map() TO authenticated;
