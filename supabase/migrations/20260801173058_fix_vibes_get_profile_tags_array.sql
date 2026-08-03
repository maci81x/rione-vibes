-- 20260801173058_fix_vibes_get_profile_tags_array
-- ricostruita da supabase_migrations.schema_migrations


CREATE OR REPLACE FUNCTION public.vibes_get_profile(p_id text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $function$
DECLARE
  v_player vibes_players;
  v_yes_count INT; v_no_count INT; v_match_count INT;
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
    'tags', _vibes_tags_as_array(v_player.tags), 'blocked', v_player.blocked,
    'created_at', v_player.created_at,
    'yes_count', v_yes_count, 'no_count', v_no_count, 'match_count', v_match_count
  );
END;
$function$;
