-- =====================================================================
-- Monako — schéma Supabase (Postgres + Auth + Storage + Realtime)
-- Fiche technique, sections 4, 9 et 11.
--
-- Principes:
--  * Aucun trait, texte ni surlignage ne contient de couleur d'affichage:
--    seulement un rôle (ink.primary, highlight.1, …).
--  * Les profils visuels sont des données sensibles: accès strictement
--    privé (jamais partagés, même avec un cahier partagé).
--  * Synchronisation: « la dernière modification gagne » pour les réglages
--    (modified_at, horodatage client), traits fusionnés et jamais effacés
--    silencieusement (pierres tombales `deleted`, jamais annulées).
--  * Suppression de compte: effacement immédiat en cascade.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Déclencheur commun: horodatage serveur + garde de fusion
-- ---------------------------------------------------------------------
create or replace function public.monako_sync_guard()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    -- Le créateur est toujours l'utilisateur connecté.
    if auth.uid() is not null then
      new.user_id := auth.uid();
    end if;
  else
    -- Le propriétaire / créateur ne change jamais.
    new.user_id := old.user_id;
    if new.modified_at < old.modified_at then
      -- Modification plus ancienne que celle déjà enregistrée: ignorée,
      -- sauf une suppression explicite, qui gagne toujours.
      if new.deleted and not old.deleted then
        new := old;
        new.deleted := true;
      else
        return null;
      end if;
    end if;
    -- Une pierre tombale n'est jamais annulée.
    if old.deleted then
      new.deleted := true;
    end if;
  end if;
  new.server_updated_at := clock_timestamp();
  return new;
end;
$$;

-- Les éléments ne changent jamais de cahier ni de page.
create or replace function public.monako_keep_parent()
returns trigger
language plpgsql
as $$
begin
  new.notebook_id := old.notebook_id;
  if tg_table_name in ('strokes', 'highlights', 'text_blocks') then
    new.page_id := old.page_id;
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- Réglages utilisateur (entité User)
-- ---------------------------------------------------------------------
create table public.user_settings (
  user_id uuid primary key references auth.users (id) on delete cascade,
  active_profile_id text not null default 'preset_standard',
  rescue_profile_id text not null default 'preset_standard',
  locale text check (locale in ('fr', 'en')),
  consent_at timestamptz,
  prefs jsonb not null default '{}'::jsonb,
  modified_at timestamptz not null default now(),
  server_updated_at timestamptz not null default clock_timestamp(),
  deleted boolean not null default false
);

-- ---------------------------------------------------------------------
-- Profils visuels (données sensibles)
-- ---------------------------------------------------------------------
create table public.visual_profiles (
  id text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null default '',
  needs text[] not null default '{}',
  -- table rôle -> couleur, ex. {"paper": "#26272B", "ink.primary": "#D9CFAF"}
  roles jsonb not null default '{}'::jsonb,
  filters jsonb not null default '{}'::jsonb,
  text jsonb not null default '{}'::jsonb,
  stroke jsonb not null default '{}'::jsonb,
  simplified_ui boolean not null default false,
  base_id text,
  modified_at timestamptz not null default now(),
  server_updated_at timestamptz not null default clock_timestamp(),
  deleted boolean not null default false,
  constraint needs_valid check (needs <@ array['A', 'B', 'C', 'D', 'E'])
);
create index visual_profiles_user_idx on public.visual_profiles (user_id, server_updated_at);

-- ---------------------------------------------------------------------
-- Dossiers et cahiers
-- ---------------------------------------------------------------------
create table public.folders (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null default '',
  parent_id uuid,
  modified_at timestamptz not null default now(),
  server_updated_at timestamptz not null default clock_timestamp(),
  deleted boolean not null default false
);
create index folders_user_idx on public.folders (user_id, server_updated_at);

create table public.notebooks (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  folder_id uuid,
  title text not null default '',
  -- profil imposé au cahier (identifiant d'un profil du propriétaire)
  linked_profile_id text,
  cover_role text not null default 'ink.accent2',
  created_at timestamptz not null default now(),
  modified_at timestamptz not null default now(),
  server_updated_at timestamptz not null default clock_timestamp(),
  deleted boolean not null default false,
  schema_version integer not null default 1
);
create index notebooks_user_idx on public.notebooks (user_id);
create index notebooks_sync_idx on public.notebooks (server_updated_at, id);
create index notebooks_title_idx on public.notebooks using gin (to_tsvector('simple', title));

-- Partage de cahiers (version 3): élèves et enseignants.
create table public.notebook_shares (
  notebook_id uuid not null references public.notebooks (id) on delete cascade,
  shared_with uuid not null references auth.users (id) on delete cascade,
  permission text not null default 'read' check (permission in ('read', 'edit')),
  created_at timestamptz not null default now(),
  primary key (notebook_id, shared_with)
);
create index notebook_shares_user_idx on public.notebook_shares (shared_with);

-- ---------------------------------------------------------------------
-- Accès aux cahiers
-- ---------------------------------------------------------------------
create or replace function public.can_access_notebook(nb uuid, need_write boolean)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
      select 1 from public.notebooks n
      where n.id = nb and n.user_id = auth.uid()
    )
    or exists (
      select 1 from public.notebook_shares s
      where s.notebook_id = nb
        and s.shared_with = auth.uid()
        and (not need_write or s.permission = 'edit')
    );
$$;

-- Ensemble des cahiers lisibles (évalué une fois par requête dans les
-- politiques de lecture, grâce au « (select …) »).
create or replace function public.my_notebook_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.notebooks where user_id = auth.uid()
  union
  select notebook_id from public.notebook_shares where shared_with = auth.uid();
$$;

-- ---------------------------------------------------------------------
-- Pages et éléments
-- ---------------------------------------------------------------------
create table public.imported_assets (
  id uuid primary key,
  notebook_id uuid not null references public.notebooks (id) on delete cascade,
  user_id uuid references auth.users (id) on delete set null,
  kind text not null check (kind in ('pdf', 'image')),
  file_name text not null default '',
  -- chemin dans le bucket `assets`: {uid}/{notebook_id}/{asset_id}.{ext}
  storage_path text,
  page_count integer not null default 1,
  -- réglages du filtre de recoloration (le fichier original n'est jamais modifié)
  filter jsonb not null default '{}'::jsonb,
  modified_at timestamptz not null default now(),
  server_updated_at timestamptz not null default clock_timestamp(),
  deleted boolean not null default false
);
create index imported_assets_sync_idx on public.imported_assets (server_updated_at, id);
create index imported_assets_nb_idx on public.imported_assets (notebook_id);

create table public.pages (
  id uuid primary key,
  notebook_id uuid not null references public.notebooks (id) on delete cascade,
  user_id uuid references auth.users (id) on delete set null,
  -- gabarit = rôle paper.line, jamais une couleur
  template text not null default 'lined' check (template in ('blank', 'lined', 'grid', 'dotted')),
  position double precision not null default 0,
  width double precision not null default 800,
  height double precision not null default 1131,
  asset_id uuid references public.imported_assets (id) on delete set null,
  asset_page integer,
  ocr_text text,
  modified_at timestamptz not null default now(),
  server_updated_at timestamptz not null default clock_timestamp(),
  deleted boolean not null default false,
  schema_version integer not null default 1
);
create index pages_sync_idx on public.pages (server_updated_at, id);
create index pages_nb_idx on public.pages (notebook_id);

-- Traits d'encre: rôle + épaisseur + points (x, y, pression) en Float32
-- little-endian encodés en base64 (format compact).
create table public.strokes (
  id uuid primary key,
  notebook_id uuid not null references public.notebooks (id) on delete cascade,
  page_id uuid not null references public.pages (id) on delete cascade,
  user_id uuid references auth.users (id) on delete set null,
  role text not null check (role in (
    'ink.primary', 'ink.secondary', 'ink.accent1', 'ink.accent2',
    'ink.accent3', 'ink.accent4', 'heading')),
  width real not null default 2.4,
  points text not null default '',
  pattern text not null default 'solid' check (pattern in ('solid', 'dashed', 'dotted', 'dashDot')),
  -- couleur libre hors rôles (fixed: true), recolorée à l'affichage
  fixed_color text check (fixed_color ~ '^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$'),
  recolor boolean not null default true,
  created_at timestamptz not null default now(),
  modified_at timestamptz not null default now(),
  server_updated_at timestamptz not null default clock_timestamp(),
  deleted boolean not null default false
);
create index strokes_sync_idx on public.strokes (server_updated_at, id);
create index strokes_page_idx on public.strokes (page_id);

create table public.highlights (
  id uuid primary key,
  notebook_id uuid not null references public.notebooks (id) on delete cascade,
  page_id uuid not null references public.pages (id) on delete cascade,
  user_id uuid references auth.users (id) on delete set null,
  role text not null check (role in ('highlight.1', 'highlight.2', 'highlight.3', 'highlight.4')),
  -- cible: tracé libre, texte, PDF ou trait
  target_type text not null default 'free' check (target_type in ('free', 'text', 'pdf', 'stroke')),
  target_id uuid,
  width real not null default 18,
  points text not null default '',
  created_at timestamptz not null default now(),
  modified_at timestamptz not null default now(),
  server_updated_at timestamptz not null default clock_timestamp(),
  deleted boolean not null default false
);
create index highlights_sync_idx on public.highlights (server_updated_at, id);
create index highlights_page_idx on public.highlights (page_id);

create table public.text_blocks (
  id uuid primary key,
  notebook_id uuid not null references public.notebooks (id) on delete cascade,
  page_id uuid not null references public.pages (id) on delete cascade,
  user_id uuid references auth.users (id) on delete set null,
  x double precision not null default 0,
  y double precision not null default 0,
  width double precision not null default 400,
  text text not null default '',
  role text not null default 'ink.primary' check (role in (
    'ink.primary', 'ink.secondary', 'ink.accent1', 'ink.accent2',
    'ink.accent3', 'ink.accent4', 'heading')),
  size real not null default 16,
  font text not null default 'system',
  modified_at timestamptz not null default now(),
  server_updated_at timestamptz not null default clock_timestamp(),
  deleted boolean not null default false
);
create index text_blocks_sync_idx on public.text_blocks (server_updated_at, id);
create index text_blocks_page_idx on public.text_blocks (page_id);
create index text_blocks_search_idx on public.text_blocks using gin (to_tsvector('simple', text));

-- ---------------------------------------------------------------------
-- Déclencheurs
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'user_settings', 'visual_profiles', 'folders', 'notebooks',
    'imported_assets', 'pages', 'strokes', 'highlights', 'text_blocks'
  ] loop
    execute format(
      'create trigger %I before insert or update on public.%I
         for each row execute function public.monako_sync_guard()',
      t || '_sync_guard', t);
  end loop;
  foreach t in array array['imported_assets', 'pages', 'strokes', 'highlights', 'text_blocks'] loop
    execute format(
      'create trigger %I before update on public.%I
         for each row execute function public.monako_keep_parent()',
      t || '_keep_parent', t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------
-- Sécurité au niveau des lignes (RLS)
-- ---------------------------------------------------------------------
alter table public.user_settings enable row level security;
alter table public.visual_profiles enable row level security;
alter table public.folders enable row level security;
alter table public.notebooks enable row level security;
alter table public.notebook_shares enable row level security;
alter table public.imported_assets enable row level security;
alter table public.pages enable row level security;
alter table public.strokes enable row level security;
alter table public.highlights enable row level security;
alter table public.text_blocks enable row level security;

-- Données strictement privées.
create policy "own settings" on public.user_settings
  for all using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "own profiles" on public.visual_profiles
  for all using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "own folders" on public.folders
  for all using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- Cahiers: propriétaire + partages.
create policy "read notebooks" on public.notebooks
  for select using (id in (select public.my_notebook_ids()));
create policy "create notebooks" on public.notebooks
  for insert with check (user_id = (select auth.uid()));
create policy "edit notebooks" on public.notebooks
  for update using (public.can_access_notebook(id, true))
  with check (public.can_access_notebook(id, true));
create policy "delete own notebooks" on public.notebooks
  for delete using (user_id = (select auth.uid()));

create policy "owner manages shares" on public.notebook_shares
  for all using (
    exists (select 1 from public.notebooks n
            where n.id = notebook_id and n.user_id = (select auth.uid()))
  )
  with check (
    exists (select 1 from public.notebooks n
            where n.id = notebook_id and n.user_id = (select auth.uid()))
  );
create policy "see my shares" on public.notebook_shares
  for select using (shared_with = (select auth.uid()));

do $$
declare t text;
begin
  foreach t in array array['imported_assets', 'pages', 'strokes', 'highlights', 'text_blocks'] loop
    execute format(
      'create policy "read %1$s" on public.%1$I for select
         using (notebook_id in (select public.my_notebook_ids()))', t);
    execute format(
      'create policy "insert %1$s" on public.%1$I for insert
         with check (public.can_access_notebook(notebook_id, true))', t);
    execute format(
      'create policy "update %1$s" on public.%1$I for update
         using (public.can_access_notebook(notebook_id, true))
         with check (public.can_access_notebook(notebook_id, true))', t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------
-- Partage (RPC)
-- ---------------------------------------------------------------------
create or replace function public.share_notebook(nb uuid, email text, perm text default 'read')
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  target uuid;
begin
  if not exists (select 1 from public.notebooks where id = nb and user_id = auth.uid()) then
    raise exception 'not_owner' using errcode = '42501';
  end if;
  if perm not in ('read', 'edit') then
    raise exception 'bad_permission';
  end if;
  select u.id into target from auth.users u
  where lower(u.email) = lower(trim(share_notebook.email));
  if target is null then
    raise exception 'user_not_found' using errcode = 'P0002';
  end if;
  if target = auth.uid() then
    raise exception 'cannot_share_with_self';
  end if;
  insert into public.notebook_shares (notebook_id, shared_with, permission)
  values (nb, target, perm)
  on conflict (notebook_id, shared_with) do update set permission = excluded.permission;
  return target;
end;
$$;

create or replace function public.list_notebook_shares(nb uuid)
returns table (user_id uuid, email text, permission text)
language sql
stable
security definer
set search_path = public
as $$
  select s.shared_with, u.email::text, s.permission
  from public.notebook_shares s
  join auth.users u on u.id = s.shared_with
  join public.notebooks n on n.id = s.notebook_id
  where s.notebook_id = nb and n.user_id = auth.uid()
  order by u.email;
$$;

create or replace function public.unshare_notebook(nb uuid, target uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.notebook_shares s
  using public.notebooks n
  where s.notebook_id = nb and s.shared_with = target
    and n.id = s.notebook_id
    and (n.user_id = auth.uid() or s.shared_with = auth.uid());
$$;

-- ---------------------------------------------------------------------
-- Suppression de compte: effacement complet et immédiat (< 30 jours exigé).
-- Les fichiers du stockage sont supprimés par l'app juste avant l'appel.
-- ---------------------------------------------------------------------
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
revoke all on function public.share_notebook(uuid, text, text) from public, anon;
grant execute on function public.share_notebook(uuid, text, text) to authenticated;
revoke all on function public.list_notebook_shares(uuid) from public, anon;
grant execute on function public.list_notebook_shares(uuid) to authenticated;
revoke all on function public.unshare_notebook(uuid, uuid) from public, anon;
grant execute on function public.unshare_notebook(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------
-- Stockage des PDF et images importés (bucket privé)
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('assets', 'assets', false, 104857600,
        array['application/pdf', 'image/png', 'image/jpeg', 'image/webp', 'image/heic', 'image/gif'])
on conflict (id) do nothing;

create policy "read assets of accessible notebooks" on storage.objects
  for select to authenticated using (
    bucket_id = 'assets'
    and ((storage.foldername(name))[2])::uuid in (select public.my_notebook_ids())
  );

create policy "upload assets to writable notebooks" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'assets'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and public.can_access_notebook(((storage.foldername(name))[2])::uuid, true)
  );

create policy "delete own uploads" on storage.objects
  for delete to authenticated using (
    bucket_id = 'assets'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- ---------------------------------------------------------------------
-- Temps réel: collaboration sur les cahiers partagés
-- ---------------------------------------------------------------------
alter publication supabase_realtime add table
  public.pages, public.strokes, public.highlights, public.text_blocks, public.notebooks;
