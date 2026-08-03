-- 20260802190217_vibes_get_profile_edits_left
-- ricostruita da supabase_migrations.schema_migrations

create or replace function public.vibes_get_profile(p_id text)
returns jsonb language plpgsql security definer as $function$
declare
  v_player vibes_players;
  v_yes_count int; v_no_count int; v_match_count int;
begin
  select * into v_player from vibes_players where id = p_id;
  if not found then return null; end if;
  select count(*) into v_yes_count from vibes_swipes where from_id = p_id and is_yes;
  select count(*) into v_no_count from vibes_swipes where from_id = p_id and not is_yes;
  select count(*) into v_match_count from vibes_matches where player_a = p_id or player_b = p_id;
  return jsonb_build_object(
    'id', v_player.id, 'pool', v_player.pool,
    'name', v_player.name, 'surname', v_player.surname,
    'birth', v_player.birth, 'photo_url', v_player.photo_url,
    'tags', _vibes_tags_as_array(v_player.tags), 'blocked', v_player.blocked,
    'created_at', v_player.created_at,
    'yes_count', v_yes_count, 'no_count', v_no_count, 'match_count', v_match_count,
    'edits_left', greatest(5 - coalesce(v_player.answer_edits,0), 0)
  );
end;
$function$;
