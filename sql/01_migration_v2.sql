-- ════════════════════════════════════════════════════════════════
-- Haushalt-Dashboard v2 – Teil 1: Migration (im Supabase SQL Editor ausführen)
-- Additiv: bestehende Daten bleiben erhalten, die alte App läuft weiter.
-- Mehrfaches Ausführen ist unschädlich.
-- ════════════════════════════════════════════════════════════════
begin;

-- 1) Neue Spalten ------------------------------------------------
alter table tasks add column if not exists section       text;   -- morgen | nachmittag | abend
alter table tasks add column if not exists days          int[];  -- 0=So … 6=Sa; NULL = täglich
alter table tasks add column if not exists weekly_target int;    -- „x von n pro Woche“
alter table tasks add column if not exists rotation      text[]; -- Wechsel zwischen Kindern
alter table tasks add column if not exists kind          text;   -- NULL | weekly | rotation | interval

alter table completions add column if not exists child_name text; -- wer bei Rotation erledigt hat

-- 2) Status 'fail' (= Kind hat abgehakt, Kontrolle sagt: nicht erledigt) erlauben
do $$
declare r record;
begin
  for r in select conname from pg_constraint
           where conrelid = 'public.completions'::regclass and contype = 'c'
             and pg_get_constraintdef(oid) ilike '%status%'
  loop
    execute format('alter table public.completions drop constraint %I', r.conname);
  end loop;
end $$;
alter table completions add constraint completions_status_check
  check (status in ('done','skip','fail'));

-- 3) Doppelte Einträge bereinigen + eindeutig machen -------------
delete from completions a using completions b
 where a.task_id = b.task_id and a.date = b.date and a.ctid < b.ctid;
create unique index if not exists completions_task_date_uq on completions(task_id, date);

delete from child_completions a using child_completions b
 where a.task_id = b.task_id and a.date = b.date
   and a.child_name is not distinct from b.child_name and a.ctid < b.ctid;
create unique index if not exists child_completions_uq on child_completions(task_id, date, child_name);

-- 4) Wochenstatus (Haus-Freitag, Finanz-Termin) ------------------
create table if not exists weekly_status (
  id          bigint generated always as identity primary key,
  week_start  date not null,          -- Montag der Woche
  key         text not null,          -- 'hausfreitag' | 'finanz'
  status      text,                   -- geplant|erledigt|verschoben  bzw.  ja|nein
  note        text,                   -- Stichworte bzw. Erklärung
  moved_to    date,
  updated_by  text,
  updated_at  timestamptz default now(),
  unique (week_start, key)
);
alter table weekly_status enable row level security;
drop policy if exists weekly_status_all on weekly_status;
create policy weekly_status_all on weekly_status
  for all to anon, authenticated using (true) with check (true);

-- 5) Haushalt: zwei neue Aufgaben ---------------------------------
insert into tasks (text, sort_order, active, list_name)
select v.text, coalesce((select max(sort_order) from tasks where list_name = 'haushalt'), 0) + v.n, true, 'haushalt'
from (values ('Bett gemacht', 1), ('Entfeuchter geleert', 2)) as v(text, n)
where not exists (select 1 from tasks t where t.list_name = 'haushalt' and t.text = v.text);

-- 6) Handy-Check (morgens durch E/B) -----------------------------
insert into tasks (text, child_name, sort_order, active, list_name)
select v.text, v.child, v.n, true, 'handycheck'
from (values ('Handy','Anton',1), ('Handy','Friedrich',2), ('Handy','Justus',3), ('iPad','Justus',4))
     as v(text, child, n)
where not exists (select 1 from tasks t where t.list_name = 'handycheck'
                  and t.text = v.text and t.child_name = v.child);

-- 7) Rasenmähen als Intervall-Aufgabe (14 Tage ab tatsächlicher Erledigung)
insert into tasks (text, sort_order, active, list_name, kind, recurrence_days, next_due_date)
select 'Rasenmähen', 1, true, 'intervall', 'interval', 14,
       coalesce((select next_due_date from tasks
                 where recurrence_days is not null and list_name <> 'intervall'
                 order by next_due_date desc nulls last limit 1), current_date)
where not exists (select 1 from tasks where list_name = 'intervall');

-- 8) Neue Kinderliste 'kinder2' ----------------------------------
--    Tage: 0=So 1=Mo … 6=Sa. NULL = jeden Tag.
insert into tasks (child_name, section, sort_order, text, days, weekly_target, kind, rotation, active, list_name)
select v.child, v.section, v.n, v.text, v.days, v.target, v.kind, v.rot, true, 'kinder2'
from (values
  -- MORGEN
  ('Anton','morgen',1,'Bett gemacht',NULL::int[],NULL::int,NULL,NULL::text[]),
  ('Anton','morgen',2,'Zähne geputzt',NULL,NULL,NULL,NULL),
  ('Friedrich','morgen',1,'Bett gemacht',NULL,NULL,NULL,NULL),
  ('Friedrich','morgen',2,'Zähne geputzt',NULL,NULL,NULL,NULL),
  ('Friedrich','morgen',3,'Hüftinnenrotation gedehnt',NULL,NULL,NULL,NULL),
  ('Justus','morgen',1,'Bett gemacht',NULL,NULL,NULL,NULL),
  ('Justus','morgen',2,'Zähne geputzt',NULL,NULL,NULL,NULL),
  -- NACHMITTAG – Anton
  ('Anton','nachmittag',1,'Hausaufgaben erledigt',NULL,NULL,NULL,NULL),
  ('Anton','nachmittag',2,'Vokabeln geübt',NULL,NULL,NULL,NULL),
  ('Anton','nachmittag',3,'Ranzen gepackt',NULL,NULL,NULL,NULL),
  ('Anton','nachmittag',4,'Flasche & Brotbox','{1,2,3,4,5}',NULL,NULL,NULL),
  ('Anton','nachmittag',5,'Oboe geübt',NULL,NULL,NULL,NULL),
  ('Anton','nachmittag',6,'Zimmer Boden frei',NULL,NULL,NULL,NULL),
  ('Anton','nachmittag',7,'Klamotten in Wäsche/Schrank',NULL,NULL,NULL,NULL),
  ('Anton','nachmittag',8,'Geschirr in Spülmaschine',NULL,NULL,NULL,NULL),
  -- NACHMITTAG – Friedrich
  ('Friedrich','nachmittag',1,'Hausaufgaben erledigt',NULL,NULL,NULL,NULL),
  ('Friedrich','nachmittag',2,'gr. Vokabeln geübt',NULL,NULL,NULL,NULL),
  ('Friedrich','nachmittag',3,'lat. Vokabeln geübt',NULL,NULL,NULL,NULL),
  ('Friedrich','nachmittag',4,'Ranzen gepackt',NULL,NULL,NULL,NULL),
  ('Friedrich','nachmittag',5,'Flasche & Brotbox','{1,2,3,4,5}',NULL,NULL,NULL),
  ('Friedrich','nachmittag',6,'Geige geübt',NULL,NULL,NULL,NULL),
  ('Friedrich','nachmittag',7,'Zimmer Boden frei',NULL,NULL,NULL,NULL),
  ('Friedrich','nachmittag',8,'Klamotten in Wäsche/Schrank',NULL,NULL,NULL,NULL),
  ('Friedrich','nachmittag',9,'Geschirr in Spülmaschine',NULL,NULL,NULL,NULL),
  ('Friedrich','nachmittag',10,'Ausgetragen','{6}',NULL,NULL,NULL),
  -- NACHMITTAG – Justus
  ('Justus','nachmittag',1,'Hausaufgaben erledigt',NULL,NULL,NULL,NULL),
  ('Justus','nachmittag',2,'griech. Vokabeln geübt',NULL,NULL,NULL,NULL),
  ('Justus','nachmittag',3,'Ranzen gepackt',NULL,NULL,NULL,NULL),
  ('Justus','nachmittag',4,'Flasche & Brotbox','{1,2,3,4,5}',NULL,NULL,NULL),
  ('Justus','nachmittag',5,'Zimmer Boden frei',NULL,NULL,NULL,NULL),
  ('Justus','nachmittag',6,'Klamotten in Wäsche/Schrank',NULL,NULL,NULL,NULL),
  ('Justus','nachmittag',7,'Geschirr in Spülmaschine',NULL,NULL,NULL,NULL),
  ('Justus','nachmittag',8,'Sport',NULL,2,'weekly',NULL),
  ('Justus','nachmittag',9,'Ausgetragen','{6}',NULL,NULL,NULL),
  -- Altglas samstags, abwechselnd J/F (Wechsel nur nach tatsächlicher Erledigung)
  (NULL,'nachmittag',20,'Altglas weggebracht','{6}',NULL,'rotation','{Justus,Friedrich}'),
  -- ABEND
  ('Anton','abend',1,'Zähne geputzt',NULL,NULL,NULL,NULL),
  ('Anton','abend',2,'Handy rausgelegt',NULL,NULL,NULL,NULL),
  ('Friedrich','abend',1,'Zähne geputzt',NULL,NULL,NULL,NULL),
  ('Friedrich','abend',2,'Handy rausgelegt',NULL,NULL,NULL,NULL),
  ('Justus','abend',1,'Zähne geputzt',NULL,NULL,NULL,NULL),
  ('Justus','abend',2,'Handy rausgelegt',NULL,NULL,NULL,NULL),
  ('Justus','abend',3,'iPad rausgelegt',NULL,NULL,NULL,NULL)
) as v(child, section, n, text, days, target, kind, rot)
where not exists (select 1 from tasks where list_name = 'kinder2');

-- 9) Abendliste der Eltern verschlanken, B-Liste stilllegen -------
--    (active=false: nichts wird gelöscht, alles bleibt in der Historie)
update tasks set active = false
 where list_name = 'abend'
   and (text ilike '%Handy raus%' or text ilike '%iPad raus%' or text ilike 'Zimmer (%');

update tasks set active = false where list_name = 'b';

commit;

-- Kontrolle: kinder2 sollte 42 Aufgaben zeigen
select list_name, count(*) from tasks where active group by list_name order by 1;
