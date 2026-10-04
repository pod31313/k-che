-- ════════════════════════════════════════════════════════════════
-- Haushalt-Dashboard – Einmalige Aufgaben anlegen/löschen erlauben
-- Fügt nur zwei Zugriffsregeln für die Tabelle "tasks" hinzu.
-- Bestehende Regeln und Daten bleiben unverändert.
-- ════════════════════════════════════════════════════════════════
do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'tasks' and policyname = 'tasks_insert_app') then
    create policy tasks_insert_app on tasks for insert to anon, authenticated with check (true);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'tasks' and policyname = 'tasks_update_app') then
    create policy tasks_update_app on tasks for update to anon, authenticated using (true) with check (true);
  end if;
end $$;

select policyname, cmd from pg_policies where tablename = 'tasks' order by 1;
