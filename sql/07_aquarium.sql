-- Aquarium-Tracking (Juwel Lido 120/200, Filter Bioflow M) – bereits per Supabase-Connector ausgeführt (12.10.2026).
-- Neue Spalte für Hinweise; Aufgaben als tasks (list_name 'aquarium', kind 'interval', child_name 'Anton').
-- "Zuletzt" liegt als completions-Eintrag (done) vor; Wasserwechsel hat nur next_due_date (26.10.2026).
alter table tasks add column if not exists note text;
-- Aufgaben/Intervalle (Tage): Wasserwechsel 14, bioPad 7, bioCarb 28, Nitrax 56, Pumpe 31,
-- bioPlus 92 (Prüfen; spätestens 9 Monate), Cirax/Impeller/LED-Ringe 365.
-- 12.10.2026: bioPlus getrennt getrackt: "reinigen (ausdrücken)" alle ~3 Monate (92 Tage), "ersetzen" alle 9 Monate (274 Tage, erster Termin 12.07.2027).
-- Nitrax: erster Termin Sa 17.10.2026 (nicht am 12.10. gewechselt).
