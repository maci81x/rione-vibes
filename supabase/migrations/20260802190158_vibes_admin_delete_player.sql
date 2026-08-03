-- 20260802190158_vibes_admin_delete_player
-- ricostruita da supabase_migrations.schema_migrations

create or replace function public.vibes_admin_delete_player(p_id text, p_token text)
returns jsonb language plpgsql security definer as $function$
begin
  if not vibes_check_admin(p_token) then
    return jsonb_build_object('error','Non autorizzato');
  end if;
  delete from vibes_messages where match_id in (select id from vibes_matches where player_a=p_id or player_b=p_id);
  delete from vibes_matches where player_a=p_id or player_b=p_id;
  delete from vibes_swipes where from_id=p_id or to_id=p_id;
  delete from vibes_players where id=p_id;
  return jsonb_build_object('ok', true);
end;
$function$;
