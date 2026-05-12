-- ReFusionXx PAP foundation.
-- Identity + device + app session + active context + pairing + agent session.

create extension if not exists pgcrypto;

create table if not exists public.refusion_devices (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null,
  device_name text,
  platform text not null default 'unknown',
  app_version text,
  status text not null default 'active' check (status in ('active', 'inactive', 'revoked')),
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(owner_id, device_id)
);

create table if not exists public.refusion_app_sessions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  device_ref uuid not null references public.refusion_devices(id) on delete cascade,
  status text not null default 'active' check (status in ('active', 'backgrounded', 'idle', 'closed')),
  started_at timestamptz not null default now(),
  last_heartbeat_at timestamptz not null default now(),
  backgrounded_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(owner_id, device_ref)
);

create table if not exists public.refusion_active_contexts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  device_ref uuid not null references public.refusion_devices(id) on delete cascade,
  app_session_id uuid not null references public.refusion_app_sessions(id) on delete cascade,
  project_id uuid not null references public.refusion_projects(id) on delete cascade,
  composition_id uuid not null references public.refusion_compositions(id) on delete cascade,
  timeline_id text not null default 'main',
  playhead_ms int not null default 0 check (playhead_ms >= 0),
  selected_layer_ids uuid[] not null default '{}',
  timeline_revision int not null default 1 check (timeline_revision > 0),
  status text not null default 'active' check (status in ('active', 'stale', 'closed')),
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique(owner_id, device_ref)
);

create table if not exists public.refusion_pairing_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  owner_id uuid not null references auth.users(id) on delete cascade,
  device_ref uuid not null references public.refusion_devices(id) on delete cascade,
  app_session_id uuid not null references public.refusion_app_sessions(id) on delete cascade,
  active_context_id uuid not null references public.refusion_active_contexts(id) on delete cascade,
  project_id uuid not null references public.refusion_projects(id) on delete cascade,
  composition_id uuid not null references public.refusion_compositions(id) on delete cascade,
  timeline_revision int not null default 1 check (timeline_revision > 0),
  status text not null default 'pending' check (status in ('pending', 'claimed', 'expired', 'revoked', 'locked')),
  failed_attempts int not null default 0 check (failed_attempts >= 0),
  generated_at timestamptz not null default now(),
  expires_at timestamptz not null,
  claimed_at timestamptz,
  claimed_by_agent text,
  revoked_at timestamptz,
  revoke_reason text
);

create table if not exists public.refusion_agent_sessions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  device_ref uuid not null references public.refusion_devices(id) on delete cascade,
  app_session_id uuid not null references public.refusion_app_sessions(id) on delete cascade,
  active_context_id uuid not null references public.refusion_active_contexts(id) on delete cascade,
  project_id uuid not null references public.refusion_projects(id) on delete cascade,
  composition_id uuid not null references public.refusion_compositions(id) on delete cascade,
  token_hash text not null unique,
  agent_client_name text,
  agent_client_version text,
  granted_capabilities text[] not null default '{}',
  status text not null default 'active' check (status in ('active', 'revoked', 'expired', 'idle')),
  created_at timestamptz not null default now(),
  last_used_at timestamptz,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  revoke_reason text
);

alter table public.refusion_agent_commands
  add column if not exists agent_session_id uuid references public.refusion_agent_sessions(id) on delete set null;

create index if not exists refusion_devices_owner_device_idx
  on public.refusion_devices(owner_id, device_id);
create index if not exists refusion_app_sessions_owner_status_idx
  on public.refusion_app_sessions(owner_id, status, last_heartbeat_at desc);
create index if not exists refusion_active_contexts_owner_device_idx
  on public.refusion_active_contexts(owner_id, device_ref, updated_at desc);
create index if not exists refusion_pairing_codes_owner_status_idx
  on public.refusion_pairing_codes(owner_id, status, expires_at desc);
create index if not exists refusion_pairing_codes_code_idx
  on public.refusion_pairing_codes(code);
create index if not exists refusion_agent_sessions_owner_project_idx
  on public.refusion_agent_sessions(owner_id, project_id, status, expires_at desc);
create index if not exists refusion_agent_sessions_token_hash_idx
  on public.refusion_agent_sessions(token_hash);
create index if not exists refusion_agent_commands_agent_session_idx
  on public.refusion_agent_commands(agent_session_id);

drop trigger if exists refusion_devices_touch_updated_at on public.refusion_devices;
create trigger refusion_devices_touch_updated_at
before update on public.refusion_devices
for each row execute function public.refusion_touch_updated_at();

drop trigger if exists refusion_app_sessions_touch_updated_at on public.refusion_app_sessions;
create trigger refusion_app_sessions_touch_updated_at
before update on public.refusion_app_sessions
for each row execute function public.refusion_touch_updated_at();

alter table public.refusion_devices enable row level security;
alter table public.refusion_app_sessions enable row level security;
alter table public.refusion_active_contexts enable row level security;
alter table public.refusion_pairing_codes enable row level security;
alter table public.refusion_agent_sessions enable row level security;

drop policy if exists refusion_devices_owner_all on public.refusion_devices;
create policy refusion_devices_owner_all
on public.refusion_devices
for all
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

drop policy if exists refusion_app_sessions_owner_all on public.refusion_app_sessions;
create policy refusion_app_sessions_owner_all
on public.refusion_app_sessions
for all
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

drop policy if exists refusion_active_contexts_owner_all on public.refusion_active_contexts;
create policy refusion_active_contexts_owner_all
on public.refusion_active_contexts
for all
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

drop policy if exists refusion_pairing_codes_owner_all on public.refusion_pairing_codes;
create policy refusion_pairing_codes_owner_all
on public.refusion_pairing_codes
for all
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

drop policy if exists refusion_agent_sessions_owner_all on public.refusion_agent_sessions;
create policy refusion_agent_sessions_owner_all
on public.refusion_agent_sessions
for all
using (owner_id = auth.uid())
with check (owner_id = auth.uid());
