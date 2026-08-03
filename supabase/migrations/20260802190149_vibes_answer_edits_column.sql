-- 20260802190149_vibes_answer_edits_column
-- ricostruita da supabase_migrations.schema_migrations

alter table public.vibes_players add column if not exists answer_edits int not null default 0;
