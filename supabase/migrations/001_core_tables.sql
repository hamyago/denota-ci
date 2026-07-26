-- ============================================================
-- DeNoTa CI — Migration 001 : Tables principales
-- ============================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";  -- géolocalisation
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- recherche floue

-- ============================================================
-- ÉNUMÉRATIONS
-- ============================================================

CREATE TYPE user_role AS ENUM (
  'athlete',       -- sportif
  'institution',   -- école / club / académie
  'recruiter',     -- recruteur / agent
  'sponsor',       -- sponsor / marque
  'expert',        -- expert notateur certifié
  'admin'          -- administrateur plateforme
);

CREATE TYPE account_status AS ENUM (
  'pending',       -- en attente de vérification
  'active',        -- actif
  'suspended',     -- suspendu
  'banned'         -- banni définitivement
);

CREATE TYPE kyc_level AS ENUM (
  'none',          -- aucune vérification
  'email',         -- email vérifié
  'phone',         -- téléphone vérifié
  'identity',      -- pièce d'identité validée
  'full'           -- vérification complète (institution/recruteur)
);

CREATE TYPE gender AS ENUM ('male', 'female', 'other');

CREATE TYPE content_type AS ENUM (
  'video', 'article', 'status', 'photo', 'story', 'live'
);

CREATE TYPE content_status AS ENUM (
  'draft', 'pending_moderation', 'published', 'rejected', 'archived'
);

CREATE TYPE subscription_plan AS ENUM (
  'free',
  'athlete_premium',
  'institution_starter',
  'institution_pro',
  'recruiter_pro',
  'sponsor_access'
);

CREATE TYPE notification_type AS ENUM (
  'profile_view', 'contact_request', 'message',
  'expert_rating', 'challenge', 'system', 'recruitment'
);

CREATE TYPE message_status AS ENUM ('sent', 'delivered', 'read');

CREATE TYPE contract_type AS ENUM (
  'professional', 'semi_pro', 'scholarship', 'internship', 'sponsorship'
);

-- ============================================================
-- TABLE : profiles (extension de auth.users)
-- ============================================================
CREATE TABLE profiles (
  id                UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role              user_role NOT NULL DEFAULT 'athlete',
  status            account_status NOT NULL DEFAULT 'pending',
  kyc_level         kyc_level NOT NULL DEFAULT 'none',
  subscription_plan subscription_plan NOT NULL DEFAULT 'free',
  subscription_expires_at TIMESTAMPTZ,

  -- Infos communes
  full_name         TEXT NOT NULL,
  username          TEXT UNIQUE NOT NULL,
  email             TEXT UNIQUE NOT NULL,
  phone             TEXT,
  avatar_url        TEXT,
  banner_url        TEXT,
  bio               TEXT,
  date_of_birth     DATE,
  gender            gender,

  -- Localisation
  country           TEXT DEFAULT 'CI',
  region            TEXT,
  city              TEXT,
  location          GEOGRAPHY(POINT, 4326), -- coordonnées GPS

  -- Paramètres
  is_minor          BOOLEAN DEFAULT FALSE,
  parental_consent  BOOLEAN DEFAULT FALSE,
  parental_email    TEXT,
  is_searchable     BOOLEAN DEFAULT TRUE,
  is_messageable    BOOLEAN DEFAULT TRUE,

  -- Métriques
  profile_views     INTEGER DEFAULT 0,
  profile_score     INTEGER DEFAULT 0, -- complétude 0-100

  -- Timestamps
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW(),
  last_seen_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Index
CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_profiles_status ON profiles(status);
CREATE INDEX idx_profiles_username ON profiles(username);
CREATE INDEX idx_profiles_location ON profiles USING GIST(location);
CREATE INDEX idx_profiles_subscription ON profiles(subscription_plan);

-- ============================================================
-- TABLE : sports
-- ============================================================
CREATE TABLE sports (
  id          SERIAL PRIMARY KEY,
  name_fr     TEXT NOT NULL,
  name_en     TEXT NOT NULL,
  slug        TEXT UNIQUE NOT NULL,
  icon_url    TEXT,
  is_active   BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE : positions (postes par sport)
-- ============================================================
CREATE TABLE positions (
  id        SERIAL PRIMARY KEY,
  sport_id  INTEGER REFERENCES sports(id) ON DELETE CASCADE,
  name_fr   TEXT NOT NULL,
  name_en   TEXT NOT NULL,
  slug      TEXT NOT NULL,
  UNIQUE(sport_id, slug)
);

-- ============================================================
-- TABLE : athlete_profiles (données sportives)
-- ============================================================
CREATE TABLE athlete_profiles (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  profile_id          UUID UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,

  -- Sport principal
  primary_sport_id    INTEGER REFERENCES sports(id),
  primary_position_id INTEGER REFERENCES positions(id),

  -- Sports secondaires
  secondary_sport_ids INTEGER[],

  -- Physique
  height_cm           DECIMAL(5,2),
  weight_kg           DECIMAL(5,2),
  dominant_foot       TEXT, -- left, right, both (foot/hand)
  jersey_number       INTEGER,

  -- Niveau
  level               TEXT, -- amateur, semi_pro, professional
  years_of_practice   INTEGER,
  availability        TEXT, -- immediate, 3_months, 6_months, not_available
  contract_types      contract_type[],

  -- Club actuel
  current_club        TEXT,
  current_institution_id UUID REFERENCES profiles(id),

  -- Talent Score (calculé)
  talent_score        DECIMAL(5,2) DEFAULT 0,
  talent_score_updated_at TIMESTAMPTZ,

  -- Réseaux sociaux
  instagram_url       TEXT,
  tiktok_url          TEXT,
  youtube_url         TEXT,

  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_athlete_sport ON athlete_profiles(primary_sport_id);
CREATE INDEX idx_athlete_score ON athlete_profiles(talent_score DESC);
CREATE INDEX idx_athlete_level ON athlete_profiles(level);

-- ============================================================
-- TABLE : institutions
-- ============================================================
CREATE TABLE institutions (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  profile_id          UUID UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,

  institution_type    TEXT, -- school, club, academy, federation
  official_name       TEXT NOT NULL,
  registration_number TEXT,
  founded_year        INTEGER,
  sport_ids           INTEGER[], -- sports pratiqués
  max_athletes        INTEGER DEFAULT 20,

  -- Adresse physique
  address             TEXT,
  website_url         TEXT,
  logo_url            TEXT,

  -- Stats
  total_athletes      INTEGER DEFAULT 0,
  champions_count     INTEGER DEFAULT 0,

  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE : recruiter_profiles
-- ============================================================
CREATE TABLE recruiter_profiles (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  profile_id        UUID UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,

  recruiter_type    TEXT, -- club, agent, sponsor, federation, media
  organization_name TEXT NOT NULL,
  organization_url  TEXT,
  license_number    TEXT, -- numéro de licence d'agent (si applicable)

  -- Préférences de recrutement
  preferred_sport_ids   INTEGER[],
  preferred_positions   INTEGER[],
  preferred_age_min     INTEGER,
  preferred_age_max     INTEGER,
  preferred_level       TEXT[],
  preferred_countries   TEXT[],
  preferred_contract    contract_type[],

  -- Métriques
  contacts_sent     INTEGER DEFAULT 0,
  recruitments_done INTEGER DEFAULT 0,

  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE : athlete_institutions (affiliations)
-- ============================================================
CREATE TABLE athlete_institutions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  athlete_id      UUID REFERENCES profiles(id) ON DELETE CASCADE,
  institution_id  UUID REFERENCES profiles(id) ON DELETE CASCADE,
  joined_at       DATE,
  left_at         DATE,
  is_current      BOOLEAN DEFAULT TRUE,
  role_in_club    TEXT, -- captain, member, youth, etc.
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(athlete_id, institution_id, is_current)
);

-- ============================================================
-- TABLE : achievements (palmarès)
-- ============================================================
CREATE TABLE achievements (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  profile_id  UUID REFERENCES profiles(id) ON DELETE CASCADE,
  title       TEXT NOT NULL,
  description TEXT,
  year        INTEGER,
  competition TEXT,
  rank        TEXT, -- 1er, finaliste, etc.
  proof_url   TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Trigger updated_at automatique
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_profiles_updated
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_athlete_updated
  BEFORE UPDATE ON athlete_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_institution_updated
  BEFORE UPDATE ON institutions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
