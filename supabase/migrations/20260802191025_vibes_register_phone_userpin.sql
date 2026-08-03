-- 20260802191025_vibes_register_phone_userpin
-- ricostruita da supabase_migrations.schema_migrations

drop function if exists public.vibes_register(text,text,date,text,jsonb);

create or replace function public.vibes_register(
  p_name text, p_surname text, p_birth date, p_photo_url text, p_tags jsonb,
  p_phone text, p_pin text
)
returns jsonb language plpgsql security definer as $function$
declare
  v_age int; v_pool text; v_id text; v_seq int; v_phone text;
begin
  v_phone := _vibes_norm_phone(p_phone);
  if v_phone is null or length(v_phone) < 8 then
    return jsonb_build_object('error','Numero di cellulare non valido');
  end if;
  if p_pin !~ '^[0-9]{4}$' then
    return jsonb_build_object('error','Il PIN deve essere di 4 cifre');
  end if;
  if exists(select 1 from vibes_players where phone = v_phone) then
    return jsonb_build_object('error','phone_duplicate');
  end if;

  v_age := extract(year from age(current_date, p_birth));
  if v_age >= 18 then
    v_pool := 'vibes'; v_seq := nextval('vibes_seq_vibes'); v_id := 'V-' || lpad(v_seq::text,3,'0');
  else
    v_pool := 'amici'; v_seq := nextval('vibes_seq_amici'); v_id := 'A-' || lpad(v_seq::text,3,'0');
  end if;

  insert into vibes_players (id, pool, name, surname, birth, photo_url, tags, pin, phone)
  values (v_id, v_pool, p_name, p_surname, p_birth, p_photo_url, p_tags, p_pin, v_phone);

  return jsonb_build_object('id', v_id, 'pin', p_pin, 'pool', v_pool);
end;
$function$;
