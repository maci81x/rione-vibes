-- 20260801170037_fix_vibes_get_candidates_jsonb_object
-- ricostruita da supabase_migrations.schema_migrations


CREATE OR REPLACE FUNCTION public.vibes_get_candidates(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_player vibes_players;
  v_result JSONB := '[]';
  v_candidate RECORD;
  v_score INT;
  v_total INT;
  v_pct INT;
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
      SELECT COUNT(*) FROM jsonb_each_text(p.tags) t(key, val)
      JOIN jsonb_each_text(v_player.tags) m(key, val) ON t.key = m.key AND t.val = m.val
    ) DESC
    LIMIT 20
  LOOP
    SELECT COUNT(*) INTO v_score
    FROM jsonb_each_text(v_candidate.tags) t(key, val)
    JOIN jsonb_each_text(v_player.tags) m(key, val)
      ON t.key = m.key AND t.val = m.val;

    v_total := (SELECT COUNT(*) FROM jsonb_each_text(v_candidate.tags));
    v_pct := ROUND(v_score::NUMERIC / GREATEST(v_total, 1) * 100);

    v_result := v_result || jsonb_build_object(
      'id', v_candidate.id, 'name', v_candidate.name,
      'photo_url', v_candidate.photo_url, 'tags', v_candidate.tags,
      'compat_pct', v_pct
    );
  END LOOP;

  RETURN v_result;
END;
$function$;
