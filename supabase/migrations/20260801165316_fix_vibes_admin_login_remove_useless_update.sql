-- 20260801165316_fix_vibes_admin_login_remove_useless_update
-- ricostruita da supabase_migrations.schema_migrations


CREATE OR REPLACE FUNCTION public.vibes_admin_login(p_pin text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_hash TEXT;
  v_stored TEXT;
  v_token TEXT;
BEGIN
  v_hash := encode(digest(p_pin, 'sha256'), 'hex');
  SELECT pin_hash INTO v_stored FROM vibes_admin WHERE id = 1;
  IF v_stored IS NULL OR v_hash != v_stored THEN
    RETURN jsonb_build_object('error', 'PIN admin errato');
  END IF;
  v_token := encode(digest(v_stored || extract(epoch from now())::text, 'sha256'), 'hex');
  RETURN jsonb_build_object('ok', true, 'token', v_token);
END;
$function$;
