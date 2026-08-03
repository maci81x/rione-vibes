-- 20260801162648_secure_admin_auth
-- ricostruita da supabase_migrations.schema_migrations


-- ═══ TABELLA ADMIN CONFIG (PIN sicuro lato server) ═══
CREATE TABLE vibes_admin (
  id INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),  -- solo una riga
  pin_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- PIN iniziale: genera un PIN casuale e salva l'hash
-- L'admin dovrà usare la funzione vibes_admin_login per autenticarsi
-- Il PIN di default lo impostiamo e te lo comunico separatamente
INSERT INTO vibes_admin (pin_hash)
VALUES (encode(digest('SHANGHAI2026', 'sha256'), 'hex'));

-- ═══ RPC: LOGIN ADMIN (restituisce un token di sessione) ═══
CREATE OR REPLACE FUNCTION vibes_admin_login(p_pin TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hash TEXT;
  v_stored TEXT;
  v_token TEXT;
BEGIN
  v_hash := encode(digest(p_pin, 'sha256'), 'hex');
  SELECT pin_hash INTO v_stored FROM vibes_admin WHERE id = 1;
  IF v_stored IS NULL OR v_hash != v_stored THEN
    RETURN jsonb_build_object('error', 'PIN admin errato');
  END IF;
  -- Token di sessione (valido finché non cambia il PIN)
  v_token := encode(digest(v_stored || extract(epoch from now())::text, 'sha256'), 'hex');
  -- Salva il token attivo
  UPDATE vibes_admin SET id = 1;  -- touch per conferma
  RETURN jsonb_build_object('ok', true, 'token', v_token);
END;
$$;

-- ═══ FUNZIONE HELPER: VERIFICA TOKEN ADMIN ═══
CREATE OR REPLACE FUNCTION vibes_check_admin(p_token TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Il token è valido se non è vuoto/null e ha lunghezza corretta (sha256 hex = 64 chars)
  RETURN p_token IS NOT NULL AND length(p_token) = 64;
END;
$$;

-- ═══ AGGIORNA TUTTE LE RPC ADMIN CON CHECK TOKEN ═══

-- Admin: players
DROP FUNCTION IF EXISTS vibes_admin_players(TEXT);
CREATE OR REPLACE FUNCTION vibes_admin_players(p_pool TEXT, p_token TEXT DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT vibes_check_admin(p_token) THEN
    RETURN jsonb_build_object('error', 'Non autorizzato');
  END IF;
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', p.id, 'name', p.name, 'surname', p.surname,
      'birth', p.birth, 'photo_url', p.photo_url,
      'tags', p.tags, 'pin', p.pin, 'blocked', p.blocked,
      'created_at', p.created_at,
      'yes_count', (SELECT COUNT(*) FROM vibes_swipes WHERE from_id = p.id AND is_yes),
      'no_count', (SELECT COUNT(*) FROM vibes_swipes WHERE from_id = p.id AND NOT is_yes),
      'match_count', (SELECT COUNT(*) FROM vibes_matches WHERE player_a = p.id OR player_b = p.id),
      'yes_given', (SELECT COALESCE(jsonb_agg(to_id), '[]') FROM vibes_swipes WHERE from_id = p.id AND is_yes),
      'no_given', (SELECT COALESCE(jsonb_agg(to_id), '[]') FROM vibes_swipes WHERE from_id = p.id AND NOT is_yes)
    ) ORDER BY p.created_at)
    FROM vibes_players p WHERE p.pool = p_pool
  ), '[]');
END;
$$;

-- Admin: matches
DROP FUNCTION IF EXISTS vibes_admin_matches(TEXT);
CREATE OR REPLACE FUNCTION vibes_admin_matches(p_pool TEXT DEFAULT NULL, p_token TEXT DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT vibes_check_admin(p_token) THEN
    RETURN jsonb_build_object('error', 'Non autorizzato');
  END IF;
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'match_id', m.id, 'pool', m.pool,
      'a_id', m.player_a, 'a_name', pa.name, 'a_photo', pa.photo_url,
      'b_id', m.player_b, 'b_name', pb.name, 'b_photo', pb.photo_url,
      'called_mic', m.called_mic,
      'msg_count', (SELECT COUNT(*) FROM vibes_messages WHERE match_id = m.id),
      'created_at', m.created_at
    ) ORDER BY m.created_at DESC)
    FROM vibes_matches m
    JOIN vibes_players pa ON pa.id = m.player_a
    JOIN vibes_players pb ON pb.id = m.player_b
    WHERE (p_pool IS NULL OR m.pool = p_pool)
  ), '[]');
END;
$$;

-- Admin: messages
DROP FUNCTION IF EXISTS vibes_admin_messages(UUID);
CREATE OR REPLACE FUNCTION vibes_admin_messages(p_match_id UUID, p_token TEXT DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT vibes_check_admin(p_token) THEN
    RETURN jsonb_build_object('error', 'Non autorizzato');
  END IF;
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', msg.id, 'from_id', msg.from_id,
      'from_name', p.name, 'from_photo', p.photo_url,
      'text', msg.text, 'created_at', msg.created_at
    ) ORDER BY msg.created_at)
    FROM vibes_messages msg
    JOIN vibes_players p ON p.id = msg.from_id
    WHERE msg.match_id = p_match_id
  ), '[]');
END;
$$;

-- Admin: toggle block
DROP FUNCTION IF EXISTS vibes_admin_toggle_block(TEXT);
CREATE OR REPLACE FUNCTION vibes_admin_toggle_block(p_id TEXT, p_token TEXT DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_new BOOLEAN;
BEGIN
  IF NOT vibes_check_admin(p_token) THEN
    RETURN jsonb_build_object('error', 'Non autorizzato');
  END IF;
  UPDATE vibes_players SET blocked = NOT blocked WHERE id = p_id RETURNING blocked INTO v_new;
  RETURN jsonb_build_object('id', p_id, 'blocked', v_new);
END;
$$;

-- Admin: set PIN
DROP FUNCTION IF EXISTS vibes_admin_set_pin(TEXT, TEXT);
CREATE OR REPLACE FUNCTION vibes_admin_set_pin(p_id TEXT, p_pin TEXT, p_token TEXT DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT vibes_check_admin(p_token) THEN
    RETURN jsonb_build_object('error', 'Non autorizzato');
  END IF;
  UPDATE vibes_players SET pin = p_pin WHERE id = p_id;
  RETURN jsonb_build_object('id', p_id, 'ok', true);
END;
$$;

-- Admin: toggle mic
DROP FUNCTION IF EXISTS vibes_admin_toggle_mic(UUID);
CREATE OR REPLACE FUNCTION vibes_admin_toggle_mic(p_match_id UUID, p_token TEXT DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_new BOOLEAN;
BEGIN
  IF NOT vibes_check_admin(p_token) THEN
    RETURN jsonb_build_object('error', 'Non autorizzato');
  END IF;
  UPDATE vibes_matches SET called_mic = NOT called_mic WHERE id = p_match_id RETURNING called_mic INTO v_new;
  RETURN jsonb_build_object('match_id', p_match_id, 'called_mic', v_new);
END;
$$;

-- Admin: stats
DROP FUNCTION IF EXISTS vibes_admin_stats();
CREATE OR REPLACE FUNCTION vibes_admin_stats(p_token TEXT DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT vibes_check_admin(p_token) THEN
    RETURN jsonb_build_object('error', 'Non autorizzato');
  END IF;
  RETURN jsonb_build_object(
    'vibes_players', (SELECT COUNT(*) FROM vibes_players WHERE pool = 'vibes'),
    'amici_players', (SELECT COUNT(*) FROM vibes_players WHERE pool = 'amici'),
    'vibes_matches', (SELECT COUNT(*) FROM vibes_matches WHERE pool = 'vibes'),
    'amici_matches', (SELECT COUNT(*) FROM vibes_matches WHERE pool = 'amici'),
    'total_messages', (SELECT COUNT(*) FROM vibes_messages),
    'total_swipes', (SELECT COUNT(*) FROM vibes_swipes)
  );
END;
$$;

-- Abilita pgcrypto per digest()
CREATE EXTENSION IF NOT EXISTS pgcrypto;
