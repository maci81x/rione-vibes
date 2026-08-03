-- 20260802191032_vibes_recover
-- ricostruita da supabase_migrations.schema_migrations

create or replace function public.vibes_recover(p_phone text)
returns jsonb language plpgsql security definer as $function$
declare v_phone text; v_p public.vibes_players;
begin
  v_phone := _vibes_norm_phone(p_phone);
  if v_phone is null then
    return jsonb_build_object('error','Numero non valido');
  end if;
  select * into v_p from vibes_players where phone = v_phone;
  if not found then
    return jsonb_build_object('error','Nessun profilo trovato con questo numero');
  end if;
  return jsonb_build_object('id', v_p.id, 'pin', v_p.pin, 'pool', v_p.pool, 'name', v_p.name);
end;
$function$;
