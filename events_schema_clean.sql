create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  event_type text not null check (event_type in ('Сессии', 'Учебная практика', 'Производственная практика')),
  description text default '',
  starts_at date not null,
  ends_at date not null,
  max_participants integer not null check (max_participants > 0),
  is_published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint events_dates_valid check (ends_at >= starts_at)
);

create table if not exists public.event_registrations (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  student_id bigint not null references public.access_keys(id) on delete cascade,
  form_data jsonb not null default '{}'::jsonb,
  status text not null default 'В процессе...' check (status in ('В процессе...', 'Готов')),
  attachment_url text,
  attachment_name text,
  attachment_path text,
  admin_comment text default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(event_id, student_id)
);

create index if not exists event_registrations_event_idx on public.event_registrations(event_id);
create index if not exists event_registrations_student_idx on public.event_registrations(student_id);

create or replace function public.register_for_event(p_event_id uuid, p_student_id bigint, p_form_data jsonb)
returns public.event_registrations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event public.events;
  v_taken integer;
  v_registration public.event_registrations;
begin
  select * into v_event from public.events where id = p_event_id and is_published = true for update;
  if not found then raise exception 'Ивент не найден или скрыт'; end if;
  select count(*) into v_taken from public.event_registrations where event_id = p_event_id;
  if v_taken >= v_event.max_participants then raise exception 'Свободных мест больше нет'; end if;
  insert into public.event_registrations(event_id, student_id, form_data)
  values (p_event_id, p_student_id, coalesce(p_form_data, '{}'::jsonb))
  returning * into v_registration;
  return v_registration;
exception when unique_violation then
  raise exception 'Вы уже записаны на этот ивент';
end;
$$;

alter table public.events enable row level security;
alter table public.event_registrations enable row level security;
drop policy if exists events_public_read on public.events;
create policy events_public_read on public.events for select using (is_published = true);
drop policy if exists events_public_write on public.events;
create policy events_public_write on public.events for all using (true) with check (true);
drop policy if exists event_registrations_public_all on public.event_registrations;
create policy event_registrations_public_all on public.event_registrations for all using (true) with check (true);

do $$ begin
  insert into storage.buckets (id, name, public)
  values ('event-results', 'event-results', true)
  on conflict (id) do nothing;
exception when others then null;
end $$;

create or replace function public.touch_events_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;
drop trigger if exists events_touch_updated_at on public.events;
create trigger events_touch_updated_at before update on public.events for each row execute function public.touch_events_updated_at();

create or replace function public.touch_event_registrations_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;
drop trigger if exists event_registrations_touch_updated_at on public.event_registrations;
create trigger event_registrations_touch_updated_at before update on public.event_registrations for each row execute function public.touch_event_registrations_updated_at();
