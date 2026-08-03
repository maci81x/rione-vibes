-- 20260801212735_fix_vibes_my_matches_tolerant
-- ricostruita da supabase_migrations.schema_migrations


CREATE OR REPLACE FUNCTION public.vibes_my_matches(p_id text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $function$
DECLARE
  v_result JSONB := '[]';
  v_match RECORD;
  v_other vibes_players;
  v_last_msg RECORD;
  v_score INT; v_total INT; v_pct INT;
  v_me vibes_players;
  v_me_tags JSONB; v_other_tags JSONB;
BEGIN
  SELECT * INTO v_me FROM vibes_players WHERE id = p_id;
  v_me_tags := _vibes_norm_tags(v_me.tags);

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

    v_other_tags := _vibes_norm_tags(v_other.tags);
    SELECT COUNT(*) INTO v_score
    FROM jsonb_each_text(v_other_tags) t(key,val)
    JOIN jsonb_each_text(v_me_tags) m(key,val) ON t.key=m.key AND t.val=m.val;
    v_total := (SELECT COUNT(*) FROM jsonb_each_text(v_other_tags));
    v_pct := ROUND(v_score::NUMERIC / GREATEST(v_total,1) * 100);

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
$function$;
