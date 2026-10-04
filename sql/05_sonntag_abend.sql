-- Anton + Friedrich: sonntags abends Duschen/Baden und Fingernägel knipsen
insert into tasks (child_name, section, sort_order, text, days, active, list_name)
select v.child, 'abend', v.n, v.text, '{0}'::int[], true, 'kinder2'
from (values
  ('Anton',     10, 'Duschen/Baden'),
  ('Anton',     11, 'Fingernägel knipsen'),
  ('Friedrich', 10, 'Duschen/Baden'),
  ('Friedrich', 11, 'Fingernägel knipsen')
) as v(child, n, text)
where not exists (select 1 from tasks t where t.list_name = 'kinder2'
                  and t.child_name = v.child and t.text = v.text);

select child_name, text, days from tasks
where list_name = 'kinder2' and section = 'abend' and active order by 1, sort_order;
