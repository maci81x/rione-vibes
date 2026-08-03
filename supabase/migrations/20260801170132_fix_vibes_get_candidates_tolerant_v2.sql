-- 20260801170132_fix_vibes_get_candidates_tolerant_v2
-- ricostruita da supabase_migrations.schema_migrations


-- Helper: normalizza i tags in un oggetto (converte array in {q1,q2,...})
CREATE OR REPLACE FUNCTION _vibes_norm_tags(t jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE jsonb_typeof(t)
    WHEN 'object' THEN t
    WHEN 'array' THEN COALESCE(
      (SELECT jsonb_object_agg('q'||idx, val)
       FROM jsonb_array_elements_text(t) WITH ORDINALITY AS x(val, idx)),
      '{}'::jsonb)
    ELSE '{}'::jsonb
  END;
$$;

CREATE OR REPLACE FUNCTION public.vibes_get_candidates(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_player vibes_players;
  v_my_tags JSONB;
  v_result JSONB := '[]';
  v_candidate RECORD;
  v_cand_tags JSONB;
  v_score INT;
  v_total INT;
  v_pct INT;
BEGIN
  SELECT * INTO v_player FROM vibes_players WHERE id = p_id;
  IF NOT FOUND THEN RETURN '[]'; END IF;
  v_my_tags := _vibes_norm_tags(v_player.tags);

  FOR v_candidate IN
    SELECT p.* FROM vibes_players p
    WHERE p.pool = v_player.pool
      AND p.id != p_id
      AND NOT p.blocked
      AND NOT EXISTS (SELECT 1 FROM vibes_swipes s WHERE s.from_id = p_id AND s.to_id = p.id)
    LIMIT 20
  LOOP
    v_cand_tags := _vibes_norm_tags(v_candidate.tags);

    SELECT COUNT(*) INTO v_score
    FROM jsonb_each_text(v_cand_tags) t(key, val)
    JOIN jsonb_each_text(v_my_tags) m(key, val)
      ON t.key = m.key AND t.val = m.val;

    v_total := (SELECT COUNT(*) FROM jsonb_each_text(v_cand_tags));
    v_pct := ROUND(v_score::NUMERIC / GREATEST(v_total, 1) * 100);

    v_result := v_result || jsonb_build_object(
      'id', v_candidate.id, 'name', v_candidate.name,
      'photo_url', v_candidate.photo_url, 'tags', v_cand_tags,
      'compat_pct', v_pct
    );
  END LOOP;

  RETURN v_result;
END;
$function$;
