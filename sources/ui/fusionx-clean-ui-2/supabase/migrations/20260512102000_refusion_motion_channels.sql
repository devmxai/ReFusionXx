create table if not exists public.refusion_motion_channels (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  project_id uuid not null references public.refusion_projects(id) on delete cascade,
  composition_id uuid not null references public.refusion_compositions(id) on delete cascade,
  layer_id uuid not null references public.refusion_layers(id) on delete cascade,
  property_id text not null,
  keyframes jsonb not null default '[]'::jsonb,
  motion_recipe text,
  created_by text not null default 'mcp-agent',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(owner_id, project_id, composition_id, layer_id, property_id)
);

create index if not exists refusion_motion_channels_project_idx
  on public.refusion_motion_channels(project_id, composition_id, layer_id);

drop trigger if exists refusion_motion_channels_touch_updated_at on public.refusion_motion_channels;
create trigger refusion_motion_channels_touch_updated_at
before update on public.refusion_motion_channels
for each row execute function public.refusion_touch_updated_at();

alter table public.refusion_motion_channels enable row level security;

drop policy if exists refusion_motion_channels_owner_all on public.refusion_motion_channels;
create policy refusion_motion_channels_owner_all
on public.refusion_motion_channels
for all
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

do $$
begin
  begin
    alter publication supabase_realtime add table public.refusion_motion_channels;
  exception
    when duplicate_object then null;
  end;
end $$;
