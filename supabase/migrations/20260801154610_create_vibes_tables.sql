-- 20260801154610_create_vibes_tables
-- ricostruita da supabase_migrations.schema_migrations


-- ═══ RIONE VIBES — TABELLE ═══

-- Giocatori
CREATE TABLE vibes_players (
  id TEXT PRIMARY KEY,                    -- V-001, A-001
  pool TEXT NOT NULL CHECK (pool IN ('vibes','amici')),  -- vibes=Kiss Nice 18+, amici=Nice is Vice <18
  name TEXT NOT NULL,
  surname TEXT NOT NULL,
  birth DATE NOT NULL,
  photo_url TEXT,                         -- URL da Supabase Storage
  tags JSONB NOT NULL DEFAULT '[]',       -- array delle 10 risposte
  pin TEXT NOT NULL,                      -- 4 cifre
  blocked BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Swipe (sì/no)
CREATE TABLE vibes_swipes (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  from_id TEXT NOT NULL REFERENCES vibes_players(id) ON DELETE CASCADE,
  to_id TEXT NOT NULL REFERENCES vibes_players(id) ON DELETE CASCADE,
  is_yes BOOLEAN NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(from_id, to_id)
);

-- Match (reciproco)
CREATE TABLE vibes_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pool TEXT NOT NULL,
  player_a TEXT NOT NULL REFERENCES vibes_players(id) ON DELETE CASCADE,
  player_b TEXT NOT NULL REFERENCES vibes_players(id) ON DELETE CASCADE,
  called_mic BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Messaggi chat
CREATE TABLE vibes_messages (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  match_id UUID NOT NULL REFERENCES vibes_matches(id) ON DELETE CASCADE,
  from_id TEXT NOT NULL REFERENCES vibes_players(id) ON DELETE CASCADE,
  text TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indici
CREATE INDEX idx_swipes_from ON vibes_swipes(from_id);
CREATE INDEX idx_swipes_to ON vibes_swipes(to_id);
CREATE INDEX idx_swipes_pair ON vibes_swipes(from_id, to_id);
CREATE INDEX idx_matches_pool ON vibes_matches(pool);
CREATE INDEX idx_matches_players ON vibes_matches(player_a, player_b);
CREATE INDEX idx_messages_match ON vibes_messages(match_id);

-- Sequenze per ID auto-incrementali per pool
CREATE SEQUENCE vibes_seq_vibes START 1;
CREATE SEQUENCE vibes_seq_amici START 1;
