-- 20260802191038_vibes_update_photo
-- ricostruita da supabase_migrations.schema_migrations

create or replace function public.vibes_update_photo(p_id text, p_pin text, p_photo_url text)
returns jsonb language plpgsql security definer as $function$
declare v_p public.vibes_players;
begin
  select * into v_p from vibes_players where id=p_id;
  if not found then return jsonb_build_object('error','Profilo non trovato'); end if;
  if v_p.pin is distinct from p_pin then return jsonb_build_object('error','PIN errato'); end if;
  if v_p.blocked then return jsonb_build_object('error','Profilo sospeso'); end if;
  update vibes_players set photo_url=p_photo_url where id=p_id;
  return jsonb_build_object('ok', true);
end;
$function$;
