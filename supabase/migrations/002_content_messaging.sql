-- ============================================================
-- DeNoTa CI — Migration 002 : Contenus & Messagerie
-- ============================================================

-- ============================================================
-- TABLE : posts (publications)
-- ============================================================
CREATE TABLE posts (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  author_id       UUID REFERENCES profiles(id) ON DELETE CASCADE,
  sport_id        INTEGER REFERENCES sports(id),

  content_type    content_type NOT NULL,
  status          content_status NOT NULL DEFAULT 'pending_moderation',

  title           TEXT,
  body            TEXT,
  tags            TEXT[],

  -- Médias
  media_urls      TEXT[], -- tableau d'URLs (vidéos, photos)
  thumbnail_url   TEXT,
  duration_sec    INTEGER, -- durée vidéo en secondes

  -- IA analyse vidéo
  ai_analyzed     BOOLEAN DEFAULT FALSE,
  ai_metrics      JSONB,  -- métriques extraites par l'IA

  -- Engagement
  views_count     INTEGER DEFAULT 0,
  likes_count     INTEGER DEFAULT 0,
  comments_count  INTEGER DEFAULT 0,
  shares_count    INTEGER DEFAULT 0,

  -- Modération
  is_flagged      BOOLEAN DEFAULT FALSE,
  flag_count      INTEGER DEFAULT 0,
  moderated_by    UUID REFERENCES profiles(id),
  moderated_at    TIMESTAMPTZ,
  rejection_reason TEXT,

  -- Visibilité
  is_public       BOOLEAN DEFAULT TRUE,
  allow_comments  BOOLEAN DEFAULT TRUE,

  published_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_posts_author ON posts(author_id);
CREATE INDEX idx_posts_sport ON posts(sport_id);
CREATE INDEX idx_posts_status ON posts(status);
CREATE INDEX idx_posts_type ON posts(content_type);
CREATE INDEX idx_posts_published ON posts(published_at DESC);
CREATE INDEX idx_posts_tags ON posts USING GIN(tags);

CREATE TRIGGER trg_posts_updated
  BEFORE UPDATE ON posts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- TABLE : post_likes
-- ============================================================
CREATE TABLE post_likes (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id    UUID REFERENCES posts(id) ON DELETE CASCADE,
  profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(post_id, profile_id)
);

-- ============================================================
-- TABLE : post_comments
-- ============================================================
CREATE TABLE post_comments (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id     UUID REFERENCES posts(id) ON DELETE CASCADE,
  author_id   UUID REFERENCES profiles(id) ON DELETE CASCADE,
  parent_id   UUID REFERENCES post_comments(id), -- réponses
  body        TEXT NOT NULL,
  is_flagged  BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_comments_post ON post_comments(post_id);

-- ============================================================
-- TABLE : athlete_stats (statistiques sportives)
-- ============================================================
CREATE TABLE athlete_stats (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  athlete_id      UUID REFERENCES profiles(id) ON DELETE CASCADE,
  sport_id        INTEGER REFERENCES sports(id),

  season          TEXT, -- ex: "2025-2026"
  competition     TEXT, -- nom du tournoi/championnat

  -- Stats générales (toujours disponibles)
  matches_played  INTEGER DEFAULT 0,
  minutes_played  INTEGER DEFAULT 0,
  wins            INTEGER DEFAULT 0,
  losses          INTEGER DEFAULT 0,
  draws           INTEGER DEFAULT 0,

  -- Stats spécifiques par sport (JSONB flexible)
  sport_stats     JSONB DEFAULT '{}',
  -- Football: {"goals":5,"assists":3,"yellow_cards":1,"red_cards":0,"passes_accuracy":85}
  -- Basketball: {"points":15,"rebounds":7,"assists":4,"steals":2,"blocks":1}
  -- Athlétisme: {"best_time_sec":10.85,"distance_m":null,"height_m":null}

  -- Stats physiques IA (extraites des vidéos)
  ai_speed_kmh    DECIMAL(5,2),
  ai_jump_cm      DECIMAL(5,2),
  ai_reaction_ms  INTEGER,
  ai_metrics      JSONB DEFAULT '{}',

  source          TEXT DEFAULT 'manual', -- manual, ai, federation_api
  verified        BOOLEAN DEFAULT FALSE,
  verified_by     UUID REFERENCES profiles(id),

  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_stats_athlete ON athlete_stats(athlete_id);
CREATE INDEX idx_stats_sport ON athlete_stats(sport_id);
CREATE INDEX idx_stats_season ON athlete_stats(season);

CREATE TRIGGER trg_stats_updated
  BEFORE UPDATE ON athlete_stats
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- TABLE : expert_ratings (notations par les experts)
-- ============================================================
CREATE TABLE expert_ratings (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  expert_id       UUID REFERENCES profiles(id) ON DELETE CASCADE,
  athlete_id      UUID REFERENCES profiles(id) ON DELETE CASCADE,

  -- Notes (1-10 chacune)
  technique_score DECIMAL(3,1) CHECK (technique_score BETWEEN 1 AND 10),
  physical_score  DECIMAL(3,1) CHECK (physical_score BETWEEN 1 AND 10),
  mental_score    DECIMAL(3,1) CHECK (mental_score BETWEEN 1 AND 10),
  stats_score     DECIMAL(3,1) CHECK (stats_score BETWEEN 1 AND 10),
  potential_score DECIMAL(3,1) CHECK (potential_score BETWEEN 1 AND 10),

  -- Score global calculé (pondéré)
  global_score    DECIMAL(4,2) GENERATED ALWAYS AS (
    ROUND(
      (technique_score * 0.30 +
       physical_score  * 0.25 +
       mental_score    * 0.20 +
       stats_score     * 0.15 +
       potential_score * 0.10)::NUMERIC, 2
    )
  ) STORED,

  comment         TEXT,
  sport_id        INTEGER REFERENCES sports(id),
  context         TEXT, -- "match_video", "live_observation", "training"

  is_public       BOOLEAN DEFAULT TRUE,
  created_at      TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(expert_id, athlete_id) -- 1 notation par expert par athlète
);

CREATE INDEX idx_ratings_athlete ON expert_ratings(athlete_id);
CREATE INDEX idx_ratings_expert ON expert_ratings(expert_id);
CREATE INDEX idx_ratings_score ON expert_ratings(global_score DESC);

-- ============================================================
-- TABLE : conversations (messagerie)
-- ============================================================
CREATE TABLE conversations (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  participant_1   UUID REFERENCES profiles(id) ON DELETE CASCADE,
  participant_2   UUID REFERENCES profiles(id) ON DELETE CASCADE,
  subject         TEXT, -- motif de la prise de contact
  contact_reason  TEXT, -- recruitment_offer, trial_invitation, sponsorship, other
  is_archived_p1  BOOLEAN DEFAULT FALSE,
  is_archived_p2  BOOLEAN DEFAULT FALSE,
  last_message_at TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(participant_1, participant_2)
);

CREATE INDEX idx_conv_p1 ON conversations(participant_1);
CREATE INDEX idx_conv_p2 ON conversations(participant_2);
CREATE INDEX idx_conv_last ON conversations(last_message_at DESC);

-- ============================================================
-- TABLE : messages
-- ============================================================
CREATE TABLE messages (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id       UUID REFERENCES profiles(id) ON DELETE CASCADE,
  body            TEXT NOT NULL,
  attachment_url  TEXT,
  status          message_status DEFAULT 'sent',
  is_flagged      BOOLEAN DEFAULT FALSE,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_messages_conv ON messages(conversation_id, created_at DESC);

-- Trigger: met à jour last_message_at dans conversations
CREATE OR REPLACE FUNCTION update_conversation_last_message()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE conversations
  SET last_message_at = NOW()
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_message_sent
  AFTER INSERT ON messages
  FOR EACH ROW EXECUTE FUNCTION update_conversation_last_message();

-- ============================================================
-- TABLE : notifications
-- ============================================================
CREATE TABLE notifications (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  recipient_id    UUID REFERENCES profiles(id) ON DELETE CASCADE,
  sender_id       UUID REFERENCES profiles(id),
  type            notification_type NOT NULL,
  title           TEXT NOT NULL,
  body            TEXT,
  data            JSONB DEFAULT '{}', -- données contextuelles
  is_read         BOOLEAN DEFAULT FALSE,
  read_at         TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notifs_recipient ON notifications(recipient_id, is_read, created_at DESC);

-- ============================================================
-- TABLE : follows (suivi de profils)
-- ============================================================
CREATE TABLE follows (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  follower_id   UUID REFERENCES profiles(id) ON DELETE CASCADE,
  following_id  UUID REFERENCES profiles(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(follower_id, following_id)
);

CREATE INDEX idx_follows_follower ON follows(follower_id);
CREATE INDEX idx_follows_following ON follows(following_id);

-- ============================================================
-- TABLE : favorites (recruteurs — athlètes sauvegardés)
-- ============================================================
CREATE TABLE favorites (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  recruiter_id  UUID REFERENCES profiles(id) ON DELETE CASCADE,
  athlete_id    UUID REFERENCES profiles(id) ON DELETE CASCADE,
  note          TEXT,
  list_name     TEXT DEFAULT 'default',
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(recruiter_id, athlete_id)
);

-- ============================================================
-- TABLE : challenges (défis sportifs communautaires)
-- ============================================================
CREATE TABLE challenges (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title           TEXT NOT NULL,
  description     TEXT,
  sport_id        INTEGER REFERENCES sports(id),
  created_by      UUID REFERENCES profiles(id),
  starts_at       TIMESTAMPTZ NOT NULL,
  ends_at         TIMESTAMPTZ NOT NULL,
  prize           TEXT,
  is_active       BOOLEAN DEFAULT TRUE,
  participants    INTEGER DEFAULT 0,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE : challenge_entries
-- ============================================================
CREATE TABLE challenge_entries (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  challenge_id    UUID REFERENCES challenges(id) ON DELETE CASCADE,
  athlete_id      UUID REFERENCES profiles(id) ON DELETE CASCADE,
  post_id         UUID REFERENCES posts(id),
  votes           INTEGER DEFAULT 0,
  rank            INTEGER,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(challenge_id, athlete_id)
);

-- ============================================================
-- TABLE : events (détections, tournois, stages)
-- ============================================================
CREATE TABLE events (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title           TEXT NOT NULL,
  description     TEXT,
  organizer_id    UUID REFERENCES profiles(id),
  sport_ids       INTEGER[],
  event_type      TEXT, -- detection, tournament, training_camp, seminar
  location_name   TEXT,
  location        GEOGRAPHY(POINT, 4326),
  address         TEXT,
  starts_at       TIMESTAMPTZ NOT NULL,
  ends_at         TIMESTAMPTZ,
  max_participants INTEGER,
  registration_fee DECIMAL(10,2) DEFAULT 0,
  currency        TEXT DEFAULT 'XOF',
  is_published    BOOLEAN DEFAULT FALSE,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_events_sport ON events USING GIN(sport_ids);
CREATE INDEX idx_events_date ON events(starts_at);
CREATE INDEX idx_events_location ON events USING GIST(location);
