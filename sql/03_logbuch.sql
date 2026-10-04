-- ════════════════════════════════════════════════════════════════
-- Haushalt-Dashboard – Logbuch für Haus-Freitag, Finanz-Termin, Rasenmähen
-- Im Supabase SQL Editor ausführen. Mehrfaches Ausführen ist unschädlich.
-- ════════════════════════════════════════════════════════════════
create table if not exists log_entries (
  id          bigint generated always as identity primary key,
  key         text not null,          -- 'hausfreitag' | 'finanz' | 'rasen'
  date        date not null,
  status      text,                   -- erledigt | verschoben | nicht erledigt
  text        text,                   -- Stichworte, mit Komma getrennt
  created_at  timestamptz default now(),
  unique (key, date)                  -- ein Eintrag pro Bereich und Tag
);
alter table log_entries enable row level security;
drop policy if exists log_entries_all on log_entries;
create policy log_entries_all on log_entries
  for all to anon, authenticated using (true) with check (true);

select 'Logbuch-Tabelle bereit' as ergebnis;
