-- 20260802191012_vibes_phone_column
-- ricostruita da supabase_migrations.schema_migrations

alter table public.vibes_players add column if not exists phone text;

create or replace function public._vibes_norm_phone(p text)
returns text language sql immutable as $$
  select nullif(regexp_replace(coalesce(p,''), '\D', '', 'g'), '')
$$;

create unique index if not exists vibes_players_phone_uidx on public.vibes_players ((phone)) where phone is not null;
