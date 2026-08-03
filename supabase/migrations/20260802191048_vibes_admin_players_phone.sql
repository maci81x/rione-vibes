-- 20260802191048_vibes_admin_players_phone
-- ricostruita da supabase_migrations.schema_migrations

create or replace function public.vibes_admin_players(p_pool text, p_token text default null::text)
returns jsonb language plpgsql security definer as $function$
begin
  if not vibes_check_admin(p_token) then
    return jsonb_build_object('error', 'Non autorizzato');
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', p.id, 'name', p.name, 'surname', p.surname,
      'birth', p.birth, 'photo_url', p.photo_url, 'phone', p.phone,
      'tags', _vibes_tags_as_array(p.tags), 'pin', p.pin, 'blocked', p.blocked,
      'created_at', p.created_at,
      'yes_count', (select count(*) from vibes_swipes where from_id = p.id and is_yes),
      'no_count', (select count(*) from vibes_swipes where from_id = p.id and not is_yes),
      'match_count', (select count(*) from vibes_matches where player_a = p.id or player_b = p.id),
      'yes_given', (select coalesce(jsonb_agg(to_id), '[]') from vibes_swipes where from_id = p.id and is_yes),
      'no_given', (select coalesce(jsonb_agg(to_id), '[]') from vibes_swipes where from_id = p.id and not is_yes)
    ) order by p.created_at)
    from vibes_players p where p.pool = p_pool
  ), '[]');
end;
$function$;
