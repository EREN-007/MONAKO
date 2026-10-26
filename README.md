# Monako

**Des notes qui s'adaptent à la vue de chaque élève.**

Monako est une app de notes (stylet, clavier, PDF annotés) du type GoodNotes dont
l'affichage s'adapte au profil visuel de chaque élève : une même note apparaît en
noir sur blanc chez un camarade et en jaune pâle sur fond gris foncé chez l'élève
photosensible, **sans que le fichier change**.

- Flutter (iPad / iPhone en priorité, Android et web avec le même code)
- **Supabase comme seul back-end** : Postgres, Auth, Storage et Realtime
- Fiche technique de référence : [`docs/fiche-technique.pdf`](docs/fiche-technique.pdf)

> Cet outil améliore le confort de lecture. Il ne remplace pas un examen de la vue
> et ne soigne aucune maladie.

---

## Démarrage rapide

### 1. Prérequis

- Flutter 3.47 (stable) — `flutter --version`
- Un projet Supabase (https://supabase.com) **ou** la CLI Supabase pour le local
- Xcode 16+ pour iOS / iPadOS (cible minimale iOS 15.5), Android Studio pour Android

### 2. Back-end Supabase

**Avec la CLI (recommandé)**

```bash
supabase login
supabase link --project-ref <votre-ref>
supabase db push            # applique supabase/migrations/*.sql
```

**Sans la CLI** : ouvrez *SQL Editor* dans le tableau de bord et exécutez le contenu de
`supabase/migrations/20261025000000_monako_schema.sql`.

Puis, dans le tableau de bord :

1. *Authentication › URL Configuration* : ajoutez `com.monako.app://login-callback`
   (et l'URL de votre site web) aux **Redirect URLs**.
2. *Authentication › Providers* : le courriel est actif par défaut. Pour **Sign in with
   Apple**, activez Apple et renseignez le Service ID et la clé.
3. Le bucket privé `assets` (PDF et images importés) est créé par la migration.

En local : `supabase start` utilise `supabase/config.toml`.

### 3. Lancer l'app

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<clé publique anon / publishable>
```

Sans ces deux valeurs, Monako fonctionne en **mode local** (sauvegarde sur l'appareil,
sans compte ni synchronisation) — pratique pour essayer l'app.

Web (CanvasKit et pdf.js sont embarqués, aucun CDN) :

```bash
flutter build web --release --no-web-resources-cdn \
  --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

### 4. Tests

```bash
flutter analyze
flutter test                         # 120+ tests
cd supabase/tests && npm install && npm test   # schéma, RLS, partage, fusion
```

La CI GitHub Actions (`.github/workflows/ci.yml`) exécute les trois.

---

## Le cœur technique : l'encre sémantique

Aucun trait, texte ni surlignage n'est enregistré avec une couleur. Chacun porte un
**rôle** (`ink.primary`, `ink.accent2`, `highlight.1`, `heading`, `paper`, …) et la
couleur réelle est calculée à l'affichage à partir du profil actif.

```json
{ "type": "stroke", "role": "ink.accent2", "width": 2.4,
  "points": [[120.5, 80.1, 0.62], [121.0, 82.4, 0.66]] }
```

- Les points sont stockés en binaire compact (Float32 little-endian, base64).
- Une couleur libre est enregistrée avec `fixed_color` et recolorée vers une couleur de
  même luminosité dans le profil (sauf si `recolor = false`).
- La base **refuse** une couleur à la place d'un rôle (contrainte `check`).
- Changer de profil = échanger une table de ~13 couleurs : aucune géométrie de trait
  n'est recalculée (mesuré : 10 ms pour 5 000 traits), avec un fondu de 200 ms.

## Profils visuels

| Profil | Fond | Encre | Ratio | Réglages |
|---|---|---|---|---|
| A1 Lumière, sombre (cas du fondateur) | `#26272B` | `#D9CFAF` | 9,6:1 | teinte chaude 30 %, plafond PDF 70 % |
| A2 Lumière, sépia doux | `#E8DCC0` | `#3A3226` | 9,3:1 | teinte chaude 20 %, pas de blanc pur |
| B Faible contraste | `#101010` | `#FFF3B0` | 16,9:1 | trait +30 %, texte +15 % |
| C Couleurs (daltonisme) | `#1B1B1F` | `#EDEDED` | 14,7:1 | accents Okabe-Ito ≥ 7:1 + motifs de trait |
| D Vision réduite | `#0F1720` | `#FFE98A` | 14,8:1 | texte +40 %, zoom 150 %, interface simplifiée |
| E Flou et distorsion | `#F3EEDD` | `#3B3B3B` | 9,6:1 | trait +25 %, interligne 1,6, mots +10 % |

Les encres d'accent, titres et surlignages de chaque profil ont été calculés en OKLCH
(`tool/generate_presets.dart`) pour atteindre la cible de contraste ; `test/contrast_test.dart`
vérifie chaque paire à chaque version. **Ces valeurs sont des hypothèses de confort à faire
valider par un optométriste avant le lancement public.**

- **Fusion** (A + C…) : fond de A, teintes de C, contraste = cible la plus haute plafonnée
  par A ; les contradictions (A + B) sont signalées et le réglage le plus sûr est retenu.
- **Outil de réglage** : ratio WCAG affiché en direct, avertissement hors plage, correction
  automatique, sélecteur de couleur OKLCH.
- **« Ce profil me fatigue »** : propose un réglage plus doux.
- **Geste de secours** : un triple toucher du doigt, n'importe où, rétablit le profil de
  secours (toujours un profil prédéfini lisible).

## Fonctionnalités

| Version | Fonction | État |
|---|---|---|
| MVP | Stylet (pression), texte clavier, surligneur, gomme, sélection (déplacer, supprimer, changer de rôle), annuler/rétablir | ✅ |
| MVP | Dossiers, cahiers, recherche par titre | ✅ |
| MVP | 6 profils + profils personnels, recoloration en direct | ✅ |
| MVP | Pastille profil toujours visible + curseurs rapides (fond, contraste, taille) | ✅ |
| MVP | Import PDF / images avec filtre de recoloration (fond → `paper`, texte → `ink.primary`, photos intactes) et « voir l'original » | ✅ |
| MVP | Sauvegarde locale (chiffrée sur mobile) + synchronisation Supabase | ✅ |
| MVP | Export PDF normal (noir sur blanc) ou dans le profil actif | ✅ |
| V2 | Profil de nuit automatique (horaire), fusion de besoins, profil imposé à un cahier | ✅ |
| V2 | Police lisible (Atkinson Hyperlegible) ou dyslexie (OpenDyslexic), interligne, espacement | ✅ |
| V2 | OCR sur l'appareil (ML Kit, iOS/Android), recherche dans le texte, lecture à voix haute, dictée | ✅ |
| V2 | Test de confort guidé à l'installation | ✅ |
| V3 | Partage de cahiers (lecture / modification) avec collaboration en temps réel | ✅ |
| V3 | Pauses visuelles 20-20-20, filtre chaud progressif en soirée | ✅ |
| V3 | Export du profil (JSON) et fiche PDF pour l'optométriste | ✅ |

## Synchronisation (Supabase)

- **Hors ligne d'abord** : toute modification est écrite localement (Hive) tout de suite,
  puis envoyée toutes les 5 s, à chaque changement de page, au retour dans l'app et chaque minute.
- **Tirer** par pagination « keyset » sur `(server_updated_at, id)`, puis **pousser** la file d'envoi.
- **Règles de fusion**, appliquées côté client *et* côté serveur (déclencheur `monako_sync_guard`) :
  la dernière modification gagne ; une suppression gagne toujours ; une pierre tombale n'est
  jamais annulée ; les traits de plusieurs appareils sont fusionnés.
- **Temps réel** : les traits d'un camarade apparaissent en direct dans un cahier partagé,
  dans *vos* couleurs.

## Confidentialité et sécurité

- Le profil visuel est une donnée sensible : table `visual_profiles` en RLS stricte
  (propriétaire seulement, **jamais partagée**, même avec un cahier partagé).
- Aucun outil publicitaire ni de suivi ; aucun CDN tiers sur le web.
- Chiffrement en transit (HTTPS) et au repos (Supabase ; Hive AES sur iOS/Android, clé dans
  le trousseau / Keystore).
- OCR traité sur l'appareil. On ne demande jamais le nom d'une maladie.
- Export de toutes les données (JSON) et suppression de compte immédiate (fichiers + cascade SQL).
- Message médical et politique de confidentialité affichés et acceptés à l'installation.
- Cadre légal à faire vérifier par un avocat : LPRPDE, Loi 25 (Québec), consentement parental
  pour les mineurs.

## Accessibilité

Cibles tactiles ≥ 48 dp, libellés VoiceOver/TalkBack sur tous les contrôles, taille de texte du
système respectée, fondus ≤ 200 ms, aucune information portée par la couleur seule (numéros,
motifs, icônes), interface en français et en anglais (`lib/l10n/*.arb`), retour haptique au
changement de profil, interface entièrement recolorée par le profil (jamais de blanc ni de noir
purs imposés). Le test de parcours web pilote l'app par son arbre d'accessibilité.

## Architecture

```
lib/
  core/
    color/        OKLCH, contraste WCAG, hex
    profiles/     modèle de profil, 6 profils + standard, plages, fusion, réglages
    render/       géométrie des traits (cache), peintres, filtre de recoloration PDF
    roles.dart    rôles d'encre sémantiques
  data/           modèles (rôles seulement), stockage local, synchronisation Supabase
  services/       profil actif, authentification, rendu PDF, export, OCR, voix
  ui/             accueil, bibliothèque, éditeur, profils, réglages, partage
  l10n/           traductions FR / EN (ARB)
supabase/
  migrations/     schéma, RLS, déclencheurs de fusion, partage, stockage, temps réel
  tests/          validation du schéma dans Postgres (PGlite)
test/             contraste, couleur, encre sémantique, fusion, recoloration,
                  performance (5 000 traits), synchro, rendu (golden), parcours complet
```

## Choix techniques et limites connues

- **Moteur de traits maison** plutôt que PencilKit : PencilKit enregistre les couleurs en dur,
  incompatible avec les rôles (point à valider de la section 8).
- **Flutter + Supabase** (colonne « alternative » de la fiche) : un seul code pour iPad, iPhone,
  Android et web, et un back-end unique.
- Les cibles de latence du stylet (< 20 ms) et 120 i/s doivent être mesurées sur iPad réel.
- Le profil automatique se base sur l'heure ; le capteur de lumière ambiante n'est pas utilisé
  (non disponible sur iOS pour les apps).
- OCR : iOS et Android seulement (pas sur le web).
- Les PDF scannés de mauvaise qualité sans texte reconnu n'ont que le filtre de couleur ;
  les graphiques à légendes colorées peuvent perdre en sens : bouton « voir l'original ».

## Licences des ressources

- Atkinson Hyperlegible © Braille Institute — SIL Open Font License (`assets/fonts/`)
- OpenDyslexic — licence Bitstream Vera (`assets/fonts/LICENSE-OpenDyslexic.txt`)
- pdf.js © Mozilla — Apache 2.0 (`web/pdfjs/LICENSE`)
