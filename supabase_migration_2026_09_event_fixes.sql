-- Миграция: исправления ивентов, PDF-результатов и статусов.
-- Выполните этот файл ОДИН РАЗ в Supabase → SQL Editor.

alter table public.event_registrations
  drop constraint if exists event_registrations_status_check;

alter table public.event_registrations
  alter column status set default 'Не оплачен';

update public.event_registrations
set status = 'Не оплачен'
where status is null or btrim(status) = '';

alter table public.event_registrations
  add constraint event_registrations_status_check
  check (status in ('Не оплачен', 'В процессе...', 'Готов'));

insert into storage.buckets (id, name, public)
values ('event-results', 'event-results', true)
on conflict (id) do update set public = true;

drop policy if exists event_results_read_public on storage.objects;
create policy event_results_read_public
on storage.objects for select
to public
using (bucket_id = 'event-results');

drop policy if exists event_results_insert_public on storage.objects;
create policy event_results_insert_public
on storage.objects for insert
to public
with check (bucket_id = 'event-results');

drop policy if exists event_results_update_public on storage.objects;
create policy event_results_update_public
on storage.objects for update
to public
using (bucket_id = 'event-results')
with check (bucket_id = 'event-results');

drop policy if exists event_results_delete_public on storage.objects;
create policy event_results_delete_public
on storage.objects for delete
to public
using (bucket_id = 'event-results');
