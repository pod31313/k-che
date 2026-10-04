-- Friedrich + Justus: freitags „Zeitungen rauslegen“; wenn nicht erledigt, am Samstag nochmal, danach weg
insert into tasks (child_name, section, sort_order, text, days, kind, recurrence_days, active, list_name)
select v.child, 'nachmittag', 15, 'Zeitungen rauslegen', '{5}'::int[], 'carry', 1, true, 'kinder2'
from (values ('Friedrich'), ('Justus')) as v(child)
where not exists (select 1 from tasks t where t.list_name = 'kinder2'
                  and t.child_name = v.child and t.text = 'Zeitungen rauslegen');

-- Justus: „Hausaufgaben erledigt“ → „Hausaufgaben bzw. 30 min gelernt“
update tasks set text = 'Hausaufgaben bzw. 30 min gelernt'
 where list_name = 'kinder2' and child_name = 'Justus' and text = 'Hausaufgaben erledigt';

select child_name, text, days, kind from tasks
where list_name = 'kinder2' and active and child_name in ('Friedrich','Justus') and section = 'nachmittag'
order by 1, sort_order;
