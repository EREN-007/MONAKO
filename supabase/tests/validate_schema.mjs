// Valide le schéma Supabase dans Postgres (PGlite), avec des substituts
// minimaux pour auth, storage et realtime: RLS, partage, fusion,
// stockage et suppression de compte.
// Usage: cd supabase/tests && npm install && npm test
import { PGlite } from '@electric-sql/pglite';
import fs from 'fs';
const db = new PGlite();
const q = (s, p) => db.query(s, p);
const ok = (c, m) => { if (!c) { console.log('ÉCHEC:', m); process.exitCode = 1; } else console.log('ok:', m); };

// --- Stubs Supabase: rôles, auth, storage, publication realtime ---
await db.exec(`
  create role anon nologin; create role authenticated nologin;
  create schema auth; create schema storage;
  create table auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as
    $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  create table storage.buckets (id text primary key, name text, public boolean,
    file_size_limit bigint, allowed_mime_types text[]);
  create table storage.objects (id uuid primary key default gen_random_uuid(), bucket_id text, name text, owner uuid);
  alter table storage.objects enable row level security;
  create or replace function storage.foldername(name text) returns text[] language sql immutable as
    $$ select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1] $$;
  create publication supabase_realtime;
`);
await db.exec(fs.readFileSync(new URL("../migrations/20261025000000_monako_schema.sql", import.meta.url), 'utf8'));
console.log('ok: migration appliquée');
await db.exec(`grant usage on schema public, auth, storage to authenticated;
  grant all on all tables in schema public to authenticated;
  grant select on auth.users to authenticated;
  grant all on storage.objects to authenticated;`);

const A = '11111111-1111-1111-1111-111111111111', B = '22222222-2222-2222-2222-222222222222', C = '33333333-3333-3333-3333-333333333333';
await q(`insert into auth.users values ($1,'a@x.ca'),($2,'b@x.ca'),($3,'c@x.ca')`, [A, B, C]);
const as = async (uid, fn) => {
  await db.exec(`set role authenticated; select set_config('request.jwt.claim.sub', '${uid}', false);`);
  try { return await fn(); } finally { await db.exec(`reset role;`); }
};
const NB = 'aaaaaaaa-0000-0000-0000-000000000001', PG = 'bbbbbbbb-0000-0000-0000-000000000001', ST = 'cccccccc-0000-0000-0000-000000000001';

// Élève A crée un cahier, une page et un trait (rôle, pas de couleur)
await as(A, async () => {
  await q(`insert into notebooks (id, user_id, title, modified_at) values ($1, $2, 'Bio', '2026-01-01')`, [NB, A]);
  await q(`insert into pages (id, notebook_id, position, modified_at) values ($1, $2, 1, '2026-01-01')`, [PG, NB]);
  await q(`insert into strokes (id, notebook_id, page_id, role, width, points, modified_at) values ($1,$2,$3,'ink.accent2',2.4,'AAAA','2026-01-01')`, [ST, NB, PG]);
  await q(`insert into visual_profiles (id, user_id, name, needs, roles) values ('prof_a', $1, 'A1', '{A}', '{"paper":"#26272B"}')`, [A]);
});
let r = await as(A, () => q(`select user_id from strokes`));
ok(r.rows[0].user_id === A, 'le créateur du trait est l’utilisateur connecté');

// Rôle invalide refusé (contrainte)
let err = null;
await as(A, async () => { try { await q(`insert into strokes (id, notebook_id, page_id, role, modified_at) values (gen_random_uuid(),$1,$2,'#000000','2026-01-01')`, [NB, PG]); } catch (e) { err = e; } });
ok(err !== null, 'une couleur à la place d’un rôle est refusée');

// RLS: B ne voit rien
r = await as(B, () => q(`select * from strokes`));
ok(r.rows.length === 0, 'RLS: B ne voit pas les traits de A');
r = await as(B, () => q(`select * from visual_profiles`));
ok(r.rows.length === 0, 'RLS: profils visuels privés');

// Partage en lecture avec B
await as(A, () => q(`select share_notebook($1, 'B@X.ca', 'read')`, [NB]));
r = await as(B, () => q(`select * from strokes`));
ok(r.rows.length === 1, 'partage: B voit le trait');
r = await as(B, () => q(`select * from visual_profiles`));
ok(r.rows.length === 0, 'partage: le profil de A reste privé');
err = null;
await as(B, async () => { try { await q(`insert into strokes (id, notebook_id, page_id, role, modified_at) values (gen_random_uuid(),$1,$2,'ink.primary','2026-01-02')`, [NB, PG]); } catch (e) { err = e; } });
ok(err !== null, 'lecture seule: B ne peut pas écrire');
r = await as(A, () => q(`select * from list_notebook_shares($1)`, [NB]));
ok(r.rows.length === 1 && r.rows[0].email === 'b@x.ca', 'liste des partages pour le propriétaire');

// Partage en modification: B ajoute un trait (upsert)
await as(A, () => q(`select share_notebook($1, 'b@x.ca', 'edit')`, [NB]));
await as(B, () => q(`insert into strokes (id, notebook_id, page_id, role, modified_at) values ('cccccccc-0000-0000-0000-000000000002',$1,$2,'ink.primary','2026-01-02')
  on conflict (id) do update set role = excluded.role, modified_at = excluded.modified_at`, [NB, PG]));
r = await as(A, () => q(`select count(*)::int n from strokes`));
ok(r.rows[0].n === 2, 'modification: le trait de B est visible par A');

// Dernière modification gagne
await as(A, () => q(`update strokes set role = 'ink.accent3', modified_at = '2026-01-05' where id = $1`, [ST]));
await as(A, () => q(`update strokes set role = 'ink.accent4', modified_at = '2026-01-03' where id = $1`, [ST]));
r = await q(`select role from strokes where id = $1`, [ST]);
ok(r.rows[0].role === 'ink.accent3', 'une modification plus ancienne est ignorée');

// Suppression plus ancienne mais gagne; pierre tombale jamais annulée
await as(A, () => q(`update strokes set deleted = true, modified_at = '2026-01-02' where id = $1`, [ST]));
r = await q(`select deleted, role from strokes where id = $1`, [ST]);
ok(r.rows[0].deleted === true && r.rows[0].role === 'ink.accent3', 'une suppression gagne toujours (sans écraser le contenu)');
await as(A, () => q(`update strokes set deleted = false, modified_at = '2026-02-01' where id = $1`, [ST]));
r = await q(`select deleted from strokes where id = $1`, [ST]);
ok(r.rows[0].deleted === true, 'une pierre tombale n’est jamais annulée');

// Le créateur et le cahier ne changent pas
await as(A, () => q(`update strokes set user_id = $2, modified_at = '2026-03-01' where id = $1`, [ST, C]));
r = await q(`select user_id from strokes where id = $1`, [ST]);
ok(r.rows[0].user_id === A, 'le créateur ne change jamais');

// server_updated_at avance à chaque écriture
const t1 = (await q(`select server_updated_at from strokes where id = $1`, [ST])).rows[0].server_updated_at;
await as(A, () => q(`update strokes set width = 3, modified_at = '2026-04-01' where id = $1`, [ST]));
const t2 = (await q(`select server_updated_at from strokes where id = $1`, [ST])).rows[0].server_updated_at;
ok(t2 > t1, 'horodatage serveur (curseur de synchro) avance');

// Collaborateur: mise à jour du titre d'un cahier partagé (pas propriétaire)
await as(B, () => q(`update notebooks set title = 'Bio 2', modified_at = '2026-05-01' where id = $1`, [NB]));
r = await q(`select title, user_id from notebooks where id = $1`, [NB]);
ok(r.rows[0].title === 'Bio 2' && r.rows[0].user_id === A, 'B modifie le titre, A reste propriétaire');

// Stockage: chemins {uid}/{notebook}/{asset}
await as(A, () => q(`insert into storage.objects (bucket_id, name) values ('assets', $1)`, [`${A}/${NB}/x.pdf`]));
r = await as(B, () => q(`select * from storage.objects`));
ok(r.rows.length === 1, 'stockage: B lit le PDF du cahier partagé');
r = await as(C, () => q(`select * from storage.objects`));
ok(r.rows.length === 0, 'stockage: C ne voit rien');
err = null;
await as(C, async () => { try { await q(`insert into storage.objects (bucket_id, name) values ('assets', $1)`, [`${C}/${NB}/y.pdf`]); } catch (e) { err = e; } });
ok(err !== null, 'stockage: C ne peut pas déposer dans le cahier de A');

// Révocation
await as(A, () => q(`select unshare_notebook($1, $2)`, [NB, B]));
r = await as(B, () => q(`select * from notebooks`));
ok(r.rows.length === 0, 'révocation: B ne voit plus le cahier');

// Suppression de compte: tout disparaît en cascade
await as(A, () => q(`select delete_my_account()`));
for (const t of ['notebooks', 'pages', 'strokes', 'visual_profiles']) {
  r = await q(`select count(*)::int n from ${t}`);
  ok(r.rows[0].n === 0, `suppression du compte: ${t} vidé`);
}
