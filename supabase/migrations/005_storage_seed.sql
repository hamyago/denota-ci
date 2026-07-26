-- ============================================================
-- DeNoTa CI — Migration 005 : Storage & Données initiales
-- ============================================================

-- ============================================================
-- STORAGE BUCKETS
-- ============================================================

-- Avatars & photos de profil
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars', 'avatars', TRUE,
  5242880, -- 5 MB
  ARRAY['image/jpeg','image/png','image/webp']
) ON CONFLICT DO NOTHING;

-- Bannières de profil
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'banners', 'banners', TRUE,
  10485760, -- 10 MB
  ARRAY['image/jpeg','image/png','image/webp']
) ON CONFLICT DO NOTHING;

-- Vidéos de performance
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'videos', 'videos', TRUE,
  524288000, -- 500 MB
  ARRAY['video/mp4','video/quicktime','video/x-msvideo','video/webm']
) ON CONFLICT DO NOTHING;

-- Photos de posts
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'posts', 'posts', TRUE,
  20971520, -- 20 MB
  ARRAY['image/jpeg','image/png','image/webp','image/gif']
) ON CONFLICT DO NOTHING;

-- Documents KYC (privé)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'kyc-documents', 'kyc-documents', FALSE,
  10485760, -- 10 MB
  ARRAY['image/jpeg','image/png','application/pdf']
) ON CONFLICT DO NOTHING;

-- Logos institutions
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'institutions', 'institutions', TRUE,
  5242880, -- 5 MB
  ARRAY['image/jpeg','image/png','image/webp','image/svg+xml']
) ON CONFLICT DO NOTHING;

-- ── Policies Storage ──────────────────────────────────────

-- Avatars : lecture publique, écriture par propriétaire
CREATE POLICY "avatars_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

CREATE POLICY "avatars_owner_write" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'avatars'
    AND auth.uid()::TEXT = (storage.foldername(name))[1]
  );

CREATE POLICY "avatars_owner_update" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'avatars'
    AND auth.uid()::TEXT = (storage.foldername(name))[1]
  );

CREATE POLICY "avatars_owner_delete" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'avatars'
    AND auth.uid()::TEXT = (storage.foldername(name))[1]
  );

-- Vidéos : lecture publique, écriture par propriétaire
CREATE POLICY "videos_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'videos');

CREATE POLICY "videos_owner_write" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'videos'
    AND auth.uid()::TEXT = (storage.foldername(name))[1]
  );

CREATE POLICY "videos_owner_delete" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'videos'
    AND auth.uid()::TEXT = (storage.foldername(name))[1]
  );

-- Documents KYC : lecture admin seulement
CREATE POLICY "kyc_admin_read" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'kyc-documents'
    AND (
      auth.uid()::TEXT = (storage.foldername(name))[1]
      OR is_admin()
    )
  );

CREATE POLICY "kyc_owner_write" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'kyc-documents'
    AND auth.uid()::TEXT = (storage.foldername(name))[1]
  );

-- Posts, banners, institutions : lecture pub, écriture propriétaire
CREATE POLICY "posts_public_read" ON storage.objects
  FOR SELECT USING (bucket_id IN ('posts','banners','institutions'));

CREATE POLICY "posts_owner_write" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id IN ('posts','banners','institutions')
    AND auth.uid()::TEXT = (storage.foldername(name))[1]
  );

-- ============================================================
-- SEED : Sports
-- ============================================================
INSERT INTO sports (name_fr, name_en, slug) VALUES
  ('Football',            'Football',          'football'),
  ('Basketball',          'Basketball',        'basketball'),
  ('Athlétisme',          'Athletics',         'athletisme'),
  ('Natation',            'Swimming',          'natation'),
  ('Handball',            'Handball',          'handball'),
  ('Volleyball',          'Volleyball',        'volleyball'),
  ('Rugby',               'Rugby',             'rugby'),
  ('Tennis',              'Tennis',            'tennis'),
  ('Arts Martiaux',       'Martial Arts',      'arts-martiaux'),
  ('Taekwondo',           'Taekwondo',         'taekwondo'),
  ('Boxe',                'Boxing',            'boxe'),
  ('Lutte',               'Wrestling',         'lutte'),
  ('Cyclisme',            'Cycling',           'cyclisme'),
  ('Judo',                'Judo',              'judo'),
  ('Karaté',              'Karate',            'karate'),
  ('Pétanque',            'Pétanque',          'petanque'),
  ('Badminton',           'Badminton',         'badminton'),
  ('Tennis de table',     'Table Tennis',      'tennis-de-table'),
  ('Golf',                'Golf',              'golf'),
  ('Triathlon',           'Triathlon',         'triathlon')
ON CONFLICT DO NOTHING;

-- ============================================================
-- SEED : Positions Football
-- ============================================================
INSERT INTO positions (sport_id, name_fr, name_en, slug)
SELECT s.id, p.name_fr, p.name_en, p.slug
FROM sports s, (VALUES
  ('Gardien de but',     'Goalkeeper',          'goalkeeper'),
  ('Défenseur central',  'Centre-back',         'centre-back'),
  ('Arrière droit',      'Right-back',          'right-back'),
  ('Arrière gauche',     'Left-back',           'left-back'),
  ('Milieu défensif',    'Defensive midfielder','defensive-mid'),
  ('Milieu central',     'Central midfielder',  'central-mid'),
  ('Milieu offensif',    'Attacking midfielder','attacking-mid'),
  ('Ailier droit',       'Right winger',        'right-winger'),
  ('Ailier gauche',      'Left winger',         'left-winger'),
  ('Avant-centre',       'Centre-forward',      'centre-forward'),
  ('Attaquant',          'Striker',             'striker')
) AS p(name_fr, name_en, slug)
WHERE s.slug = 'football'
ON CONFLICT DO NOTHING;

-- ============================================================
-- SEED : Positions Basketball
-- ============================================================
INSERT INTO positions (sport_id, name_fr, name_en, slug)
SELECT s.id, p.name_fr, p.name_en, p.slug
FROM sports s, (VALUES
  ('Meneur',        'Point Guard',    'point-guard'),
  ('Arrière',       'Shooting Guard', 'shooting-guard'),
  ('Ailier',        'Small Forward',  'small-forward'),
  ('Ailier fort',   'Power Forward',  'power-forward'),
  ('Pivot',         'Center',         'center')
) AS p(name_fr, name_en, slug)
WHERE s.slug = 'basketball'
ON CONFLICT DO NOTHING;

-- ============================================================
-- SEED : Positions Athlétisme
-- ============================================================
INSERT INTO positions (sport_id, name_fr, name_en, slug)
SELECT s.id, p.name_fr, p.name_en, p.slug
FROM sports s, (VALUES
  ('Sprint (100m-200m)',     'Sprint',          'sprint'),
  ('Demi-fond (400m-800m)', 'Middle distance',  'middle-distance'),
  ('Fond (1500m+)',          'Long distance',    'long-distance'),
  ('Haies',                  'Hurdles',          'hurdles'),
  ('Saut en hauteur',        'High jump',        'high-jump'),
  ('Saut en longueur',       'Long jump',        'long-jump'),
  ('Triple saut',            'Triple jump',      'triple-jump'),
  ('Lancer du javelot',      'Javelin',          'javelin'),
  ('Lancer du disque',       'Discus',           'discus'),
  ('Marche athlétique',      'Race walk',        'race-walk')
) AS p(name_fr, name_en, slug)
WHERE s.slug = 'athletisme'
ON CONFLICT DO NOTHING;

-- ============================================================
-- SEED : Pays (Afrique de l'Ouest prioritaires)
-- ============================================================
CREATE TABLE IF NOT EXISTS countries (
  code   CHAR(2) PRIMARY KEY,
  name_fr TEXT NOT NULL,
  name_en TEXT NOT NULL,
  flag_emoji TEXT,
  is_priority BOOLEAN DEFAULT FALSE
);

INSERT INTO countries (code, name_fr, name_en, flag_emoji, is_priority) VALUES
  ('CI', 'Côte d''Ivoire',      'Ivory Coast',        '🇨🇮', TRUE),
  ('SN', 'Sénégal',             'Senegal',             '🇸🇳', TRUE),
  ('GH', 'Ghana',               'Ghana',               '🇬🇭', TRUE),
  ('NG', 'Nigeria',             'Nigeria',             '🇳🇬', TRUE),
  ('ML', 'Mali',                'Mali',                '🇲🇱', TRUE),
  ('BF', 'Burkina Faso',        'Burkina Faso',        '🇧🇫', TRUE),
  ('GN', 'Guinée',              'Guinea',              '🇬🇳', TRUE),
  ('TG', 'Togo',                'Togo',                '🇹🇬', TRUE),
  ('BJ', 'Bénin',               'Benin',               '🇧🇯', TRUE),
  ('NE', 'Niger',               'Niger',               '🇳🇪', TRUE),
  ('MR', 'Mauritanie',          'Mauritania',          '🇲🇷', FALSE),
  ('LR', 'Libéria',             'Liberia',             '🇱🇷', FALSE),
  ('SL', 'Sierra Leone',        'Sierra Leone',        '🇸🇱', FALSE),
  ('GM', 'Gambie',              'Gambia',              '🇬🇲', FALSE),
  ('GW', 'Guinée-Bissau',       'Guinea-Bissau',       '🇬🇼', FALSE),
  ('CV', 'Cap-Vert',            'Cape Verde',          '🇨🇻', FALSE),
  ('CM', 'Cameroun',            'Cameroon',            '🇨🇲', FALSE),
  ('FR', 'France',              'France',              '🇫🇷', FALSE),
  ('BE', 'Belgique',            'Belgium',             '🇧🇪', FALSE)
ON CONFLICT DO NOTHING;

-- ============================================================
-- SEED : Villes de Côte d'Ivoire
-- ============================================================
CREATE TABLE IF NOT EXISTS cities (
  id       SERIAL PRIMARY KEY,
  name     TEXT NOT NULL,
  country  CHAR(2) REFERENCES countries(code),
  region   TEXT,
  is_major BOOLEAN DEFAULT FALSE
);

INSERT INTO cities (name, country, region, is_major) VALUES
  ('Abidjan',        'CI', 'Abidjan',         TRUE),
  ('Yamoussoukro',   'CI', 'Yamoussoukro',    TRUE),
  ('Bouaké',         'CI', 'Vallée du Bandama', TRUE),
  ('Daloa',          'CI', 'Haut-Sassandra',  TRUE),
  ('Korhogo',        'CI', 'Poro',            TRUE),
  ('San Pédro',      'CI', 'San-Pédro',       TRUE),
  ('Man',            'CI', 'Tonkpi',          FALSE),
  ('Gagnoa',         'CI', 'Gôh',             FALSE),
  ('Abengourou',     'CI', 'Indénié-Djuablin',FALSE),
  ('Divo',           'CI', 'Lôh-Djiboua',     FALSE),
  ('Soubré',         'CI', 'Nawa',            FALSE),
  ('Agboville',      'CI', 'Agnéby-Tiassa',   FALSE),
  ('Boundiali',      'CI', 'Hambol',          FALSE),
  ('Odienné',        'CI', 'Kabadougou',      FALSE),
  ('Séguéla',        'CI', 'Worodougou',      FALSE),
  ('Ferkessédougou', 'CI', 'Hambol',          FALSE)
ON CONFLICT DO NOTHING;

COMMIT;
