-- 20260802190208_vibes_update_tags
-- ricostruita da supabase_migrations.schema_migrations

create or replace function public.vibes_update_tags(p_id text, p_pin text, p_tags jsonb)
returns jsonb language plpgsql security definer as $function$
declare v_p public.vibes_players;
begin
  select * into v_p from vibes_players where id=p_id;
  if not found then return jsonb_build_object('error','Profilo non trovato'); end if;
  if v_p.pin is distinct from p_pin then return jsonb_build_object('error','PIN errato'); end if;
  if v_p.blocked then return jsonb_build_object('error','Profilo sospeso'); end if;
  if coalesce(v_p.answer_edits,0) >= 5 then
    return jsonb_build_object('error','Hai esaurito le 5 modifiche','edits_left',0);
  end if;
  update vibes_players set tags=p_tags, answer_edits=coalesce(answer_edits,0)+1 where id=p_id;
  return jsonb_build_object('ok', true, 'edits_left', 5 - (coalesce(v_p.answer_edits,0)+1));
end;
$function$;
