-- 20260801154714_create_vibes_rpcs
-- ricostruita da supabase_migrations.schema_migrations


-- ═══ RPC: REGISTRAZIONE ═══
CREATE OR REPLACE FUNCTION vibes_register(
  p_name TEXT,
  p_surname TEXT,
  p_birth DATE,
  p_photo_url TEXT,
  p_tags JSONB
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_age INT;
  v_pool TEXT;
  v_id TEXT;
  v_pin TEXT;
  v_seq INT;
BEGIN
  v_age := EXTRACT(YEAR FROM age(CURRENT_DATE, p_birth));
  IF v_age >= 18 THEN
    v_pool := 'vibes';
    v_seq := nextval('vibes_seq_vibes');
    v_id := 'V-' || LPAD(v_seq::TEXT, 3, '0');
  ELSE
    v_pool := 'amici';
    v_seq := nextval('vibes_seq_amici');
    v_id := 'A-' || LPAD(v_seq::TEXT, 3, '0');
  END IF;
  v_pin := LPAD((floor(random() * 9000) + 1000)::TEXT, 4, '0');

  INSERT INTO vibes_players (id, pool, name, surname, birth, photo_url, tags, pin)
  VALUES (v_id, v_pool, p_name, p_surname, p_birth, p_photo_url, p_tags, v_pin);

  RETURN jsonb_build_object('id', v_id, 'pin', v_pin, 'pool', v_pool);
END;
$$;

-- ═══ RPC: LOGIN ═══
CREATE OR REPLACE FUNCTION vibes_login(
  p_code TEXT,
  p_pin TEXT
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_player vibes_players;
BEGIN
  SELECT * INTO v_player FROM vibes_players WHERE id = p_code;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Codice non trovato');
  END IF;
  IF v_player.blocked THEN
    RETURN jsonb_build_object('error', 'Account sospeso.');
  END IF;
  IF v_player.pin != p_pin THEN
    RETURN jsonb_build_object('error', 'PIN errato');
  END IF;
  RETURN jsonb_build_object(
    'id', v_player.id, 'pool', v_player.pool,
    'name', v_player.name, 'surname', v_player.surname,
    'photo_url', v_player.photo_url, 'tags', v_player.tags,
    'blocked', v_player.blocked, 'created_at', v_player.created_at
  );
END;
$$;

-- ═══ RPC: PROFILO UTENTE COMPLETO ═══
CREATE OR REPLACE FUNCTION vibes_get_profile(p_id TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_player vibes_players;
  v_yes_count INT;
  v_no_count INT;
  v_match_count INT;
BEGIN
  SELECT * INTO v_player FROM vibes_players WHERE id = p_id;
  IF NOT FOUND THEN RETURN NULL; END IF;
  SELECT COUNT(*) INTO v_yes_count FROM vibes_swipes WHERE from_id = p_id AND is_yes;
  SELECT COUNT(*) INTO v_no_count FROM vibes_swipes WHERE from_id = p_id AND NOT is_yes;
  SELECT COUNT(*) INTO v_match_count FROM vibes_matches WHERE player_a = p_id OR player_b = p_id;
  RETURN jsonb_build_object(
    'id', v_player.id, 'pool', v_player.pool,
    'name', v_player.name, 'surname', v_player.surname,
    'birth', v_player.birth, 'photo_url', v_player.photo_url,
    'tags', v_player.tags, 'blocked', v_player.blocked,
    'created_at', v_player.created_at,
    'yes_count', v_yes_count, 'no_count', v_no_count, 'match_count', v_match_count
  );
END;
$$;

-- ═══ RPC: CANDIDATI PER SWIPE (ordinati per compatibilità) ═══
CREATE OR REPLACE FUNCTION vibes_get_candidates(p_id TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_player vibes_players;
  v_result JSONB := '[]';
  v_candidate RECORD;
  v_score INT;
  v_pct INT;
  v_tags JSONB;
BEGIN
  SELECT * INTO v_player FROM vibes_players WHERE id = p_id;
  IF NOT FOUND THEN RETURN '[]'; END IF;

  FOR v_candidate IN
    SELECT p.* FROM vibes_players p
    WHERE p.pool = v_player.pool
      AND p.id != p_id
      AND NOT p.blocked
      AND NOT EXISTS (SELECT 1 FROM vibes_swipes s WHERE s.from_id = p_id AND s.to_id = p.id)
    ORDER BY (
      SELECT COUNT(*) FROM jsonb_array_elements_text(p.tags) WITH ORDINALITY AS t(val, idx)
      JOIN jsonb_array_elements_text(v_player.tags) WITH ORDINALITY AS m(val, idx) ON t.idx = m.idx AND t.val = m.val
    ) DESC
    LIMIT 20
  LOOP
    SELECT COUNT(*) INTO v_score
    FROM jsonb_array_elements_text(v_candidate.tags) WITH ORDINALITY AS t(val, idx)
    JOIN jsonb_array_elements_text(v_player.tags) WITH ORDINALITY AS m(val, idx)
      ON t.idx = m.idx AND t.val = m.val;
    v_pct := ROUND(v_score::NUMERIC / GREATEST(jsonb_array_length(v_candidate.tags), 1) * 100);

    v_result := v_result || jsonb_build_object(
      'id', v_candidate.id, 'name', v_candidate.name,
      'photo_url', v_candidate.photo_url, 'tags', v_candidate.tags,
      'compat_pct', v_pct
    );
  END LOOP;

  RETURN v_result;
END;
$$;

-- ═══ RPC: SWIPE (con check match automatico) ═══
CREATE OR REPLACE FUNCTION vibes_swipe(
  p_from TEXT,
  p_to TEXT,
  p_is_yes BOOLEAN
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_mutual BOOLEAN := false;
  v_match_id UUID;
  v_pool TEXT;
  v_to_name TEXT;
BEGIN
  INSERT INTO vibes_swipes (from_id, to_id, is_yes) VALUES (p_from, p_to, p_is_yes)
  ON CONFLICT (from_id, to_id) DO NOTHING;

  IF p_is_yes THEN
    SELECT is_yes INTO v_mutual FROM vibes_swipes WHERE from_id = p_to AND to_id = p_from;
    IF v_mutual IS TRUE THEN
      SELECT pool INTO v_pool FROM vibes_players WHERE id = p_from;
      SELECT name INTO v_to_name FROM vibes_players WHERE id = p_to;
      INSERT INTO vibes_matches (pool, player_a, player_b)
      VALUES (v_pool, p_from, p_to) RETURNING id INTO v_match_id;
      RETURN jsonb_build_object('match', true, 'match_id', v_match_id, 'match_name', v_to_name);
    END IF;
  END IF;

  RETURN jsonb_build_object('match', false);
END;
$$;

-- ═══ RPC: I MIEI MATCH ═══
CREATE OR REPLACE FUNCTION vibes_my_matches(p_id TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_result JSONB := '[]';
  v_match RECORD;
  v_other vibes_players;
  v_last_msg RECORD;
  v_unread INT;
  v_score INT;
  v_pct INT;
  v_me vibes_players;
BEGIN
  SELECT * INTO v_me FROM vibes_players WHERE id = p_id;
  FOR v_match IN
    SELECT * FROM vibes_matches
    WHERE player_a = p_id OR player_b = p_id
    ORDER BY created_at DESC
  LOOP
    IF v_match.player_a = p_id THEN
      SELECT * INTO v_other FROM vibes_players WHERE id = v_match.player_b;
    ELSE
      SELECT * INTO v_other FROM vibes_players WHERE id = v_match.player_a;
    END IF;

    SELECT * INTO v_last_msg FROM vibes_messages WHERE match_id = v_match.id ORDER BY created_at DESC LIMIT 1;

    SELECT COUNT(*) INTO v_score
    FROM jsonb_array_elements_text(v_other.tags) WITH ORDINALITY AS t(val, idx)
    JOIN jsonb_array_elements_text(v_me.tags) WITH ORDINALITY AS m(val, idx) ON t.idx = m.idx AND t.val = m.val;
    v_pct := ROUND(v_score::NUMERIC / GREATEST(jsonb_array_length(v_other.tags), 1) * 100);

    v_result := v_result || jsonb_build_object(
      'match_id', v_match.id,
      'other_id', v_other.id, 'other_name', v_other.name,
      'other_photo', v_other.photo_url, 'compat_pct', v_pct,
      'last_msg', COALESCE(v_last_msg.text, ''),
      'last_msg_time', v_last_msg.created_at,
      'created_at', v_match.created_at
    );
  END LOOP;
  RETURN v_result;
END;
$$;

-- ═══ RPC: MESSAGGI DI UN MATCH ═══
CREATE OR REPLACE FUNCTION vibes_get_messages(p_match_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', m.id, 'from_id', m.from_id, 'text', m.text, 'created_at', m.created_at
    ) ORDER BY m.created_at)
    FROM vibes_messages m WHERE m.match_id = p_match_id
  ), '[]');
END;
$$;

-- ═══ RPC: INVIA MESSAGGIO ═══
CREATE OR REPLACE FUNCTION vibes_send_message(
  p_match_id UUID,
  p_from TEXT,
  p_text TEXT
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id BIGINT;
BEGIN
  INSERT INTO vibes_messages (match_id, from_id, text)
  VALUES (p_match_id, p_from, p_text)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('id', v_id);
END;
$$;

-- ═══ RPC: ADMIN — TUTTI I GIOCATORI DI UN POOL ═══
CREATE OR REPLACE FUNCTION vibes_admin_players(p_pool TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
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

-- ═══ RPC: ADMIN — TUTTI I MATCH DI UN POOL ═══
CREATE OR REPLACE FUNCTION vibes_admin_matches(p_pool TEXT DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
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

-- ═══ RPC: ADMIN — MESSAGGI DI UN MATCH (con nomi) ═══
CREATE OR REPLACE FUNCTION vibes_admin_messages(p_match_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
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

-- ═══ RPC: ADMIN — BLOCCA/SBLOCCA ═══
CREATE OR REPLACE FUNCTION vibes_admin_toggle_block(p_id TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_new BOOLEAN;
BEGIN
  UPDATE vibes_players SET blocked = NOT blocked WHERE id = p_id RETURNING blocked INTO v_new;
  RETURN jsonb_build_object('id', p_id, 'blocked', v_new);
END;
$$;

-- ═══ RPC: ADMIN — CAMBIA PIN ═══
CREATE OR REPLACE FUNCTION vibes_admin_set_pin(p_id TEXT, p_pin TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE vibes_players SET pin = p_pin WHERE id = p_id;
  RETURN jsonb_build_object('id', p_id, 'ok', true);
END;
$$;

-- ═══ RPC: ADMIN — SEGNA CHIAMATI AL MICROFONO ═══
CREATE OR REPLACE FUNCTION vibes_admin_toggle_mic(p_match_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_new BOOLEAN;
BEGIN
  UPDATE vibes_matches SET called_mic = NOT called_mic WHERE id = p_match_id RETURNING called_mic INTO v_new;
  RETURN jsonb_build_object('match_id', p_match_id, 'called_mic', v_new);
END;
$$;

-- ═══ RPC: ADMIN — STATISTICHE PANORAMICA ═══
CREATE OR REPLACE FUNCTION vibes_admin_stats()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
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

-- Abilita realtime sulla tabella messaggi per notifiche
ALTER PUBLICATION supabase_realtime ADD TABLE vibes_messages;
