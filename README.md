# Rione Vibes — Kiss is Nice / Nice is Vice

Mini-app matching per l'evento Shanghai Vice del Rione Shanghai — 28 agosto 2026.

Stack: HTML + Vanilla JS + Supabase.

## Backend

Progetto Supabase `kbcrtwqtzuipcsfiyupu` (org "Associazione il Dragone"),
**condiviso con shanghai-card**: stesso database, due app logiche distinte.

RPC principali: `vibes_register_phone_userpin`, `vibes_get_candidates`,
`vibes_swipe`, `vibes_my_matches`, `vibes_admin_login`, `vibes_admin_players`.

Il PIN admin è hashato sha256 nella tabella `vibes_admin` — non è in chiaro
nel codice.

## Migration

`supabase/migrations/` contiene le 20 migration di questa app (schema, RPC,
admin auth).

Poiché il DB è condiviso, la divisione tra i due repo segue il nome della
migration: appartengono a rione-vibes quelle che iniziano con `vibes_`,
`create_vibes_`, `fix_vibes_`, più `secure_admin_auth`. Tutto il resto sta
in shanghai-card.

I file non sono stati scritti a mano: sono stati ricostruiti dalla tabella
`supabase_migrations.schema_migrations` del progetto remoto, perché fino ad
agosto 2026 le migration venivano applicate in produzione via MCP Supabase
senza copia nei repo. Lo script che le rigenera è `scripts/dump-migrations.sh`
nel repo shanghai-card; rigenera tutte e 118 le migration del DB, quindi le
20 di rione-vibes vanno poi rispostate qui.

### Convenzioni

- Nome file: `TIMESTAMP_nome.sql`, nome unico globale su tutto il DB
- Prima di `CREATE OR REPLACE FUNCTION` con signature diversa: sempre
  `DROP FUNCTION IF EXISTS ...` esplicito
- Applicazione via MCP Supabase, poi ricostruzione del file e commit
