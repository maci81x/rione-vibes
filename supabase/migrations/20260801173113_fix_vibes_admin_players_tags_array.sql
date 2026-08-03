-- 20260801173113_fix_vibes_admin_players_tags_array
-- ricostruita da supabase_migrations.schema_migrations


CREATE OR REPLACE FUNCTION public.vibes_admin_players(p_pool text, p_token text DEFAULT NULL::text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $function$
BEGIN
  IF NOT vibes_check_admin(p_token) THEN
    RETURN jsonb_build_object('error', 'Non autorizzato');
  END IF;
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', p.id, 'name', p.name, 'surname', p.surname,
      'birth', p.birth, 'photo_url', p.photo_url,
      'tags', _vibes_tags_as_array(p.tags), 'pin', p.pin, 'blocked', p.blocked,
      'created_at', p.created_at,
      'yes_count', (SELECT COUNT(*) FROM vibes_swipes WHERE from_id = p.id AND is_yes),
      'no_count', (SELECT COUNT(*) FROM vibes_swipes WHERE from_id = p.id AND NOT is_yes),
      'match_count', (SELECT COUNT(*) FROM vibes_matches WHERE player_a = p.id OR player_b = p.id),
      'yes_given', (SELECT COALESCE(jsonb_agg(to_id), '[]') FROM vibes_swipes WHERE from_id = p.id AND is_yes),
      'no_given', (SELECT COALESCE(jsonb_agg(to_id), '[]') FROM vibes_swipes WHERE from_id = p.id AND NOT is_yes)
    ) ORDER BY p.created_at)
    FROM vibes_players p WHERE p.pool = p_pool
  ), '[]');
END;
$function$;
