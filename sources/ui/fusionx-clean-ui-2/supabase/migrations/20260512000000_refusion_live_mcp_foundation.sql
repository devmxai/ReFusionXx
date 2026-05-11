-- ReFusionXx Live MCP foundation.
-- Source of truth for authenticated project editing, live editor sessions,
-- realtime command delivery, and revision-safe MCP mutations.

create extension if not exists pgcrypto;

create table if not exists public.refusion_projects (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null default 'Untitled Project',
  status text not null default 'active' check (status in ('active', 'archived', 'deleted')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.refusion_compositions (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.refusion_projects(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null default 'Composition 1',
  aspect text not null default 'story',
  width int not null default 1080 check (width > 0),
  height int not null default 1920 check (height > 0),
  fps int not null default 30 check (fps > 0),
  duration_ms int not null default 8000 check (duration_ms > 0),
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.refusion_project_revisions (
  project_id uuid primary key references public.refusion_projects(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  revision int not null default 1 check (revision > 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.refusion_layers (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.refusion_projects(id) on delete cascade,
  composition_id uuid not null references public.refusion_compositions(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  parent_layer_id uuid references public.refusion_layers(id) on delete set null,
  layer_kind text not null check (
    layer_kind in (
      'solid',
      'adjustment',
      'media',
      'text',
      'shape',
      'audio',
      'scene_program'
    )
  ),
  name text not null default 'Layer',
  start_ms int not null default 0 check (start_ms >= 0),
  duration_ms int not null default 3000 check (duration_ms > 0),
  z_index int not null default 0,
  payload jsonb not null default '{}'::jsonb,
  created_by text not null default 'user',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.refusion_editor_sessions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null,
  project_id uuid references public.refusion_projects(id) on delete set null,
  composition_id uuid references public.refusion_compositions(id) on delete set null,
  timeline_id text not null default 'main',
  playhead_ms int not null default 0 check (playhead_ms >= 0),
  timeline_revision int not null default 1 check (timeline_revision > 0),
  status text not null default 'online' check (status in ('online', 'background', 'offline')),
  foreground boolean not null default true,
  app_version text,
  platform text,
  metadata jsonb not null default '{}'::jsonb,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(owner_id, device_id)
);

create table if not exists public.refusion_agent_commands (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  project_id uuid references public.refusion_projects(id) on delete cascade,
  composition_id uuid references public.refusion_compositions(id) on delete cascade,
  editor_session_id uuid references public.refusion_editor_sessions(id) on delete set null,
  command_type text not null,
  payload jsonb not null default '{}'::jsonb,
  expected_revision int,
  revision_before int,
  revision_after int,
  status text not null default 'pending' check (
    status in ('pending', 'running', 'succeeded', 'failed', 'cancelled')
  ),
  idempotency_key text,
  result jsonb not null default '{}'::jsonb,
  error_message text,
  created_at timestamptz not null default now(),
  claimed_at timestamptz,
  completed_at timestamptz,
  updated_at timestamptz not null default now()
);

create unique index if not exists refusion_agent_commands_idempotency_idx
  on public.refusion_agent_commands(owner_id, idempotency_key)
  where idempotency_key is not null;

create table if not exists public.refusion_audit_events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users(id) on delete set null,
  project_id uuid references public.refusion_projects(id) on delete set null,
  composition_id uuid references public.refusion_compositions(id) on delete set null,
  actor text not null default 'system',
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists refusion_projects_owner_idx
  on public.refusion_projects(owner_id, updated_at desc);
create index if not exists refusion_compositions_project_idx
  on public.refusion_compositions(project_id, is_active desc, updated_at desc);
create index if not exists refusion_layers_composition_idx
  on public.refusion_layers(composition_id, z_index asc, start_ms asc);
create index if not exists refusion_editor_sessions_owner_status_idx
  on public.refusion_editor_sessions(owner_id, status, foreground, last_seen_at desc);
create index if not exists refusion_agent_commands_owner_status_idx
  on public.refusion_agent_commands(owner_id, status, created_at asc);

create or replace function public.refusion_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists refusion_projects_touch_updated_at on public.refusion_projects;
create trigger refusion_projects_touch_updated_at
before update on public.refusion_projects
for each row execute function public.refusion_touch_updated_at();

drop trigger if exists refusion_compositions_touch_updated_at on public.refusion_compositions;
create trigger refusion_compositions_touch_updated_at
before update on public.refusion_compositions
for each row execute function public.refusion_touch_updated_at();

drop trigger if exists refusion_layers_touch_updated_at on public.refusion_layers;
create trigger refusion_layers_touch_updated_at
before update on public.refusion_layers
for each row execute function public.refusion_touch_updated_at();

drop trigger if exists refusion_editor_sessions_touch_updated_at on public.refusion_editor_sessions;
create trigger refusion_editor_sessions_touch_updated_at
before update on public.refusion_editor_sessions
for each row execute function public.refusion_touch_updated_at();

drop trigger if exists refusion_agent_commands_touch_updated_at on public.refusion_agent_commands;
create trigger refusion_agent_commands_touch_updated_at
before update on public.refusion_agent_commands
for each row execute function public.refusion_touch_updated_at();

alter table public.refusion_projects enable row level security;
alter table public.refusion_compositions enable row level security;
alter table public.refusion_project_revisions enable row level security;
alter table public.refusion_layers enable row level security;
alter table public.refusion_editor_sessions enable row level security;
alter table public.refusion_agent_commands enable row level security;
alter table public.refusion_audit_events enable row level security;

drop policy if exists refusion_projects_owner_all on public.refusion_projects;
create policy refusion_projects_owner_all
on public.refusion_projects
for all
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

drop policy if exists refusion_compositions_owner_all on public.refusion_compositions;
create policy refusion_compositions_owner_all
on public.refusion_compositions
for all
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

drop policy if exists refusion_project_revisions_owner_all on public.refusion_project_revisions;
create policy refusion_project_revisions_owner_all
on public.refusion_project_revisions
for all
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

drop policy if exists refusion_layers_owner_all on public.refusion_layers;
create policy refusion_layers_owner_all
on public.refusion_layers
for all
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

drop policy if exists refusion_editor_sessions_owner_all on public.refusion_editor_sessions;
create policy refusion_editor_sessions_owner_all
on public.refusion_editor_sessions
for all
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

drop policy if exists refusion_agent_commands_owner_all on public.refusion_agent_commands;
create policy refusion_agent_commands_owner_all
on public.refusion_agent_commands
for all
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

drop policy if exists refusion_audit_events_owner_read on public.refusion_audit_events;
create policy refusion_audit_events_owner_read
on public.refusion_audit_events
for select
using (owner_id = auth.uid());

create or replace function public.refusion_increment_project_revision(target_project_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  next_revision int;
begin
  update public.refusion_project_revisions
     set revision = revision + 1,
         updated_at = now()
   where project_id = target_project_id
   returning revision into next_revision;

  if next_revision is null then
    raise exception 'Project revision not found: %', target_project_id
      using errcode = 'P0002';
  end if;

  return next_revision;
end;
$$;

create or replace function public.refusion_create_project(
  project_name text default 'Untitled Project',
  composition_name text default 'Story',
  composition_aspect text default 'story',
  composition_width int default 1080,
  composition_height int default 1920,
  composition_duration_ms int default 8000,
  composition_fps int default 30
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  new_project_id uuid;
  new_composition_id uuid;
begin
  if current_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  insert into public.refusion_projects(owner_id, name)
  values (current_user_id, coalesce(nullif(project_name, ''), 'Untitled Project'))
  returning id into new_project_id;

  insert into public.refusion_compositions(
    project_id,
    owner_id,
    name,
    aspect,
    width,
    height,
    duration_ms,
    fps,
    is_active
  )
  values (
    new_project_id,
    current_user_id,
    coalesce(nullif(composition_name, ''), 'Story'),
    coalesce(nullif(composition_aspect, ''), 'story'),
    greatest(coalesce(composition_width, 1080), 1),
    greatest(coalesce(composition_height, 1920), 1),
    greatest(coalesce(composition_duration_ms, 8000), 1),
    greatest(coalesce(composition_fps, 30), 1),
    true
  )
  returning id into new_composition_id;

  insert into public.refusion_project_revisions(project_id, owner_id, revision)
  values (new_project_id, current_user_id, 1);

  insert into public.refusion_audit_events(owner_id, project_id, composition_id, actor, event_type)
  values (current_user_id, new_project_id, new_composition_id, 'user', 'project.created');

  return jsonb_build_object(
    'projectId', new_project_id,
    'compositionId', new_composition_id,
    'revision', 1
  );
end;
$$;

create or replace function public.refusion_touch_editor_session(
  p_device_id text,
  p_project_id uuid default null,
  p_composition_id uuid default null,
  p_timeline_id text default 'main',
  p_playhead_ms int default 0,
  p_timeline_revision int default 1,
  p_foreground boolean default true,
  p_status text default 'online',
  p_app_version text default null,
  p_platform text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  session_id uuid;
begin
  if current_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if p_device_id is null or length(trim(p_device_id)) = 0 then
    raise exception 'device_id is required' using errcode = '22023';
  end if;

  insert into public.refusion_editor_sessions(
    owner_id,
    device_id,
    project_id,
    composition_id,
    timeline_id,
    playhead_ms,
    timeline_revision,
    foreground,
    status,
    app_version,
    platform,
    metadata,
    last_seen_at
  )
  values (
    current_user_id,
    trim(p_device_id),
    p_project_id,
    p_composition_id,
    coalesce(nullif(p_timeline_id, ''), 'main'),
    greatest(coalesce(p_playhead_ms, 0), 0),
    greatest(coalesce(p_timeline_revision, 1), 1),
    coalesce(p_foreground, true),
    coalesce(nullif(p_status, ''), 'online'),
    p_app_version,
    p_platform,
    coalesce(p_metadata, '{}'::jsonb),
    now()
  )
  on conflict (owner_id, device_id)
  do update set
    project_id = excluded.project_id,
    composition_id = excluded.composition_id,
    timeline_id = excluded.timeline_id,
    playhead_ms = excluded.playhead_ms,
    timeline_revision = excluded.timeline_revision,
    foreground = excluded.foreground,
    status = excluded.status,
    app_version = excluded.app_version,
    platform = excluded.platform,
    metadata = excluded.metadata,
    last_seen_at = now(),
    updated_at = now()
  returning id into session_id;

  return jsonb_build_object(
    'sessionId', session_id,
    'online', true
  );
end;
$$;

create or replace function public.refusion_get_active_context()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  live_session public.refusion_editor_sessions%rowtype;
  project_row public.refusion_projects%rowtype;
  composition_row public.refusion_compositions%rowtype;
  revision_value int;
begin
  if current_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  select *
    into live_session
    from public.refusion_editor_sessions
   where owner_id = current_user_id
     and status in ('online', 'background')
     and last_seen_at > now() - interval '45 seconds'
   order by foreground desc, last_seen_at desc
   limit 1;

  if live_session.project_id is not null then
    select * into project_row
      from public.refusion_projects
     where id = live_session.project_id and owner_id = current_user_id;
  else
    select * into project_row
      from public.refusion_projects
     where owner_id = current_user_id and status = 'active'
     order by updated_at desc
     limit 1;
  end if;

  if project_row.id is null then
    return jsonb_build_object(
      'hasProject', false,
      'liveEditor', jsonb_build_object('online', false)
    );
  end if;

  if live_session.composition_id is not null then
    select * into composition_row
      from public.refusion_compositions
     where id = live_session.composition_id
       and project_id = project_row.id
       and owner_id = current_user_id;
  end if;

  if composition_row.id is null then
    select * into composition_row
      from public.refusion_compositions
     where project_id = project_row.id and owner_id = current_user_id
     order by is_active desc, updated_at desc
     limit 1;
  end if;

  select revision into revision_value
    from public.refusion_project_revisions
   where project_id = project_row.id;

  return jsonb_build_object(
    'hasProject', true,
    'project', jsonb_build_object(
      'id', project_row.id,
      'name', project_row.name,
      'revision', coalesce(revision_value, 1)
    ),
    'composition', jsonb_build_object(
      'id', composition_row.id,
      'name', composition_row.name,
      'aspect', composition_row.aspect,
      'width', composition_row.width,
      'height', composition_row.height,
      'fps', composition_row.fps,
      'durationMs', composition_row.duration_ms
    ),
    'timeline', jsonb_build_object(
      'id', coalesce(live_session.timeline_id, 'main'),
      'playheadMs', coalesce(live_session.playhead_ms, 0)
    ),
    'liveEditor', jsonb_build_object(
      'online', live_session.id is not null,
      'sessionId', live_session.id,
      'deviceId', live_session.device_id,
      'foreground', coalesce(live_session.foreground, false),
      'lastSeenAt', live_session.last_seen_at
    )
  );
end;
$$;

create or replace function public.refusion_insert_layer(
  p_project_id uuid,
  p_composition_id uuid,
  p_layer_kind text,
  p_name text default 'Layer',
  p_start_ms int default 0,
  p_duration_ms int default 3000,
  p_z_index int default 0,
  p_payload jsonb default '{}'::jsonb,
  p_expected_revision int default null,
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  current_revision int;
  next_revision int;
  new_layer_id uuid;
  new_command_id uuid;
begin
  if current_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  select revision into current_revision
    from public.refusion_project_revisions
   where project_id = p_project_id and owner_id = current_user_id
   for update;

  if current_revision is null then
    raise exception 'Project not found or not owned by current user' using errcode = 'P0002';
  end if;
  if p_expected_revision is not null and p_expected_revision != current_revision then
    raise exception 'Revision conflict. expected %, actual %', p_expected_revision, current_revision
      using errcode = '40001';
  end if;

  if not exists (
    select 1
      from public.refusion_compositions
     where id = p_composition_id
       and project_id = p_project_id
       and owner_id = current_user_id
  ) then
    raise exception 'Composition not found or not owned by current user' using errcode = 'P0002';
  end if;

  insert into public.refusion_layers(
    project_id,
    composition_id,
    owner_id,
    layer_kind,
    name,
    start_ms,
    duration_ms,
    z_index,
    payload,
    created_by
  )
  values (
    p_project_id,
    p_composition_id,
    current_user_id,
    p_layer_kind,
    coalesce(nullif(p_name, ''), 'Layer'),
    greatest(coalesce(p_start_ms, 0), 0),
    greatest(coalesce(p_duration_ms, 3000), 1),
    coalesce(p_z_index, 0),
    coalesce(p_payload, '{}'::jsonb),
    'mcp'
  )
  returning id into new_layer_id;

  next_revision := public.refusion_increment_project_revision(p_project_id);

  insert into public.refusion_agent_commands(
    owner_id,
    project_id,
    composition_id,
    command_type,
    payload,
    expected_revision,
    revision_before,
    revision_after,
    status,
    idempotency_key,
    result,
    completed_at
  )
  values (
    current_user_id,
    p_project_id,
    p_composition_id,
    'refusion.insert_layer',
    jsonb_build_object(
      'layerId', new_layer_id,
      'layerKind', p_layer_kind,
      'name', coalesce(nullif(p_name, ''), 'Layer'),
      'payload', coalesce(p_payload, '{}'::jsonb)
    ),
    p_expected_revision,
    current_revision,
    next_revision,
    'succeeded',
    p_idempotency_key,
    jsonb_build_object('layerId', new_layer_id),
    now()
  )
  returning id into new_command_id;

  insert into public.refusion_audit_events(
    owner_id,
    project_id,
    composition_id,
    actor,
    event_type,
    payload
  )
  values (
    current_user_id,
    p_project_id,
    p_composition_id,
    'mcp',
    'layer.inserted',
    jsonb_build_object('layerId', new_layer_id, 'commandId', new_command_id)
  );

  return jsonb_build_object(
    'ok', true,
    'projectId', p_project_id,
    'compositionId', p_composition_id,
    'layerId', new_layer_id,
    'commandId', new_command_id,
    'revisionBefore', current_revision,
    'revisionAfter', next_revision
  );
end;
$$;

create or replace function public.refusion_enqueue_command(
  p_project_id uuid,
  p_composition_id uuid,
  p_command_type text,
  p_payload jsonb default '{}'::jsonb,
  p_expected_revision int default null,
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  current_revision int;
  new_command_id uuid;
begin
  if current_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  select revision into current_revision
    from public.refusion_project_revisions
   where project_id = p_project_id and owner_id = current_user_id;

  if current_revision is null then
    raise exception 'Project not found or not owned by current user' using errcode = 'P0002';
  end if;
  if p_expected_revision is not null and p_expected_revision != current_revision then
    raise exception 'Revision conflict. expected %, actual %', p_expected_revision, current_revision
      using errcode = '40001';
  end if;

  insert into public.refusion_agent_commands(
    owner_id,
    project_id,
    composition_id,
    command_type,
    payload,
    expected_revision,
    revision_before,
    status,
    idempotency_key
  )
  values (
    current_user_id,
    p_project_id,
    p_composition_id,
    p_command_type,
    coalesce(p_payload, '{}'::jsonb),
    p_expected_revision,
    current_revision,
    'pending',
    p_idempotency_key
  )
  returning id into new_command_id;

  return jsonb_build_object(
    'ok', true,
    'commandId', new_command_id,
    'status', 'pending',
    'revisionBefore', current_revision
  );
end;
$$;

create or replace function public.refusion_complete_command(
  p_command_id uuid,
  p_status text,
  p_result jsonb default '{}'::jsonb,
  p_error_message text default null,
  p_revision_after int default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  update public.refusion_agent_commands
     set status = p_status,
         result = coalesce(p_result, '{}'::jsonb),
         error_message = p_error_message,
         revision_after = p_revision_after,
         completed_at = case when p_status in ('succeeded', 'failed', 'cancelled') then now() else completed_at end,
         updated_at = now()
   where id = p_command_id
     and owner_id = current_user_id;

  if not found then
    raise exception 'Command not found or not owned by current user' using errcode = 'P0002';
  end if;

  return jsonb_build_object('ok', true, 'commandId', p_command_id, 'status', p_status);
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.refusion_projects;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.refusion_compositions;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.refusion_layers;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.refusion_editor_sessions;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.refusion_agent_commands;
exception when duplicate_object then null;
end $$;
