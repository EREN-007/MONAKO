-- =====================================================================
-- Monako v2 (peut être relancé sans erreur) — favoris, corbeille, signets et plan, types de document,
-- types de stylo, nouveaux gabarits, images posées sur une page.
-- =====================================================================

-- Cahiers: favori, type (cahier, tableau blanc, note rapide), corbeille.
alter table public.notebooks
  add column if not exists favorite boolean not null default false,
  add column if not exists kind text not null default 'notebook'
    check (kind in ('notebook', 'whiteboard', 'quicknote')),
  add column if not exists trashed_at timestamptz;

-- Pages: signet, titre dans le plan, nouveaux gabarits.
alter table public.pages
  add column if not exists bookmarked boolean not null default false,
  add column if not exists outline_title text;
alter table public.pages drop constraint if exists pages_template_check;
alter table public.pages add constraint pages_template_check
  check (template in ('blank', 'lined', 'narrow', 'grid', 'dotted', 'cornell'));

-- Traits: type de stylo (la géométrie dépend de la pression).
alter table public.strokes
  add column if not exists pen text not null default 'fountain'
    check (pen in ('ball', 'fountain', 'brush', 'shape'));

-- Images posées sur une page (photo de tableau, schéma…).
-- Le fichier est dans imported_assets / le bucket `assets`, jamais modifié.
create table if not exists public.page_images (
  id uuid primary key,
  notebook_id uuid not null references public.notebooks (id) on delete cascade,
  page_id uuid not null references public.pages (id) on delete cascade,
  user_id uuid references auth.users (id) on delete set null,
  asset_id uuid references public.imported_assets (id) on delete cascade,
  x double precision not null default 0,
  y double precision not null default 0,
  width double precision not null default 200,
  height double precision not null default 200,
  created_at timestamptz not null default now(),
  modified_at timestamptz not null default now(),
  server_updated_at timestamptz not null default clock_timestamp(),
  deleted boolean not null default false
);
create index if not exists page_images_sync_idx on public.page_images (server_updated_at, id);
create index if not exists page_images_page_idx on public.page_images (page_id);

drop trigger if exists page_images_sync_guard on public.page_images;
drop trigger if exists page_images_keep_parent on public.page_images;
create trigger page_images_sync_guard before insert or update on public.page_images
  for each row execute function public.monako_sync_guard();
create trigger page_images_keep_parent before update on public.page_images
  for each row execute function public.monako_keep_parent();

alter table public.page_images enable row level security;
drop policy if exists "read page_images" on public.page_images;
drop policy if exists "insert page_images" on public.page_images;
drop policy if exists "update page_images" on public.page_images;
create policy "read page_images" on public.page_images for select
  using (notebook_id in (select public.my_notebook_ids()));
create policy "insert page_images" on public.page_images for insert
  with check (public.can_access_notebook(notebook_id, true));
create policy "update page_images" on public.page_images for update
  using (public.can_access_notebook(notebook_id, true))
  with check (public.can_access_notebook(notebook_id, true));

-- Les images gardent leur page.
create or replace function public.monako_keep_parent()
returns trigger
language plpgsql
as $$
begin
  new.notebook_id := old.notebook_id;
  if tg_table_name in ('strokes', 'highlights', 'text_blocks', 'page_images') then
    new.page_id := old.page_id;
  end if;
  return new;
end;
$$;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'page_images'
  ) then
    alter publication supabase_realtime add table public.page_images;
  end if;
end;
$$;
