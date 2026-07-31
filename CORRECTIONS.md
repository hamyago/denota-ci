# DeNoTa — Corrections appliquées

## Bugs corrigés (code Flutter)

1. **« Modifier le profil » inactif** → navigation câblée vers `EditProfileScreen`
   (menu réglages + bouton du header). Rechargement automatique du profil au retour.
   Fichier : `profile_screen.dart`.

2. **Photo de profil / bannière non ajoutées** → deux causes :
   - MIME corrigé (`image/jpeg` au lieu de `image/jpg`, refusé par le bucket) ;
   - cache-busting (`?v=timestamp`) pour forcer le rafraîchissement après ré-upload.
   Fichier : `profile_repository.dart`. **+ policies UPDATE Storage** (migration 006).

3. **Vidéos non enregistrées** → MIME dynamique : un `.mov` iPhone envoie
   désormais `video/quicktime` (et non `video/mov`, rejeté). Mapping complet
   mov/avi/webm/mp4. Fichier : `video_service.dart`.

4. **Articles & statuts non enregistrés** → même correctif MIME sur les images
   (`image/jpeg`, `image/png`…). De plus, le propriétaire voit maintenant ses
   posts `pending_moderation` sur son profil (badge « En attente »), pour ne plus
   croire que rien n'a été sauvegardé. Fichiers : `video_service.dart`,
   `profile_repository.dart`, `profile_screen.dart`.

5. **Bouton « Passer en Premium » mort** → trois causes :
   - `onPressed: () {}` remplacé par une navigation vers `PaymentScreen`
     (plan Sportif Premium présélectionné) ;
   - la table `payment_attempts` **n'existait pas** en base → migration 006 ;
   - imports câblés. Fichier : `conversations_screen.dart`.

## Améliorations / nettoyage

- **Feed** : la requête embarque désormais l'auteur (`profiles` + `athlete_profiles`)
  → noms, avatars, sport et talent score s'affichent (avant : toujours null).
  Parsing de la relation `athlete_profiles` corrigé (liste, pas map).
- **Inscription** : après `signUp`, l'écran de **choix du rôle** (`RegisterRoleScreen`)
  s'affiche enfin, puis redirige vers l'accueil.
- **Fichiers morts supprimés** : `otp_screen.dart`, `register_role_screen.dart`,
  `home/discover_screen.dart`, `messaging/chat_screen.dart` (simples ré-exports
  jamais importés).
- **Imports inutiles retirés** (`supabase_flutter` dans `register_screen.dart`),
  branche de compression morte nettoyée dans `create_post_screen.dart`.

## ⚠️ À FAIRE côté Supabase

Exécuter **`supabase/migrations/006_payments_storage.sql`** dans le SQL Editor du
projet `denota-ci`. Sans elle :
- aucun paiement ne peut aboutir (table `payment_attempts` absente) ;
- le ré-upload d'avatar/bannière échoue (policy UPDATE manquante).

## Note sécurité

La table `public.spatial_ref_sys` (PostGIS) a la RLS désactivée. C'est une table
système en lecture seule et sans données sensibles ; ce n'est pas bloquant, mais
si tu veux fermer l'avertissement Supabase :
`ALTER TABLE public.spatial_ref_sys ENABLE ROW LEVEL SECURITY;`
(elle deviendra alors inaccessible en lecture — à ne faire que si tu n'utilises
pas PostGIS côté client).

---

# Mise à jour — Dashboard multi-rôles (version finale)

Fusion de la version corrigée (tous les correctifs ci-dessus) avec la
fonctionnalité **dashboard** développée dans `denota-fixed-v16`.

## Ce qui a été ajouté

- **`admin/admin_dashboard_screen.dart`** — tableau de bord administrateur
  à 3 onglets :
  - *Vue globale* : statistiques (utilisateurs, actifs, posts, en attente) ;
  - *Modération* : liste des posts `pending_moderation` avec boutons
    Publier / Rejeter ;
  - *Utilisateurs* : liste des inscrits avec activation / suspension.
- **`home_shell.dart` désormais multi-rôles** : le premier onglet s'adapte
  au rôle du profil connecté —
  - `admin` → Dashboard admin,
  - `recruiter` → Dashboard recruteur,
  - autres (athlete/institution/sponsor) → Fil d'actualité.

## Corrections apportées au dashboard lors de la fusion

1. **`use_build_context_synchronously`** — `_moderatePost` et
   `_toggleUserStatus` utilisaient `context` après un `await` sans garde.
   Ajout de `if (!mounted) return;` (sinon le CI `flutter analyze` échoue,
   comme lors du build précédent).
2. **Publication depuis la modération** — quand l'admin publie un post,
   on renseigne aussi `published_at`, sinon le post n'apparaît pas dans le
   feed (qui trie par `published_at`).

## Prérequis base de données

- Les policies `posts_admin_all` et `profiles_admin_all` (fonction
  `is_admin()`) existent déjà → l'admin peut tout lire/modérer. ✓
- **Toujours à exécuter** : `supabase/migrations/006_payments_storage.sql`
  (paiements + upload avatar/bannière).

## Pour tester le dashboard admin

Le dashboard n'apparaît que pour un profil `role = 'admin'`. Promeus un
compte de test (garde ton compte athlète pour le reste) :

```sql
UPDATE profiles SET role = 'admin' WHERE email = 'TON_EMAIL_ADMIN';
```

Puis reconnecte-toi : le premier onglet devient « Admin ».

---

# Mise à jour — Identité visuelle (icône + logo)

## Fichiers ajoutés
- `assets/images/icone.png` — l'icône seule (sans texte).
- `assets/images/logo.png` — le logo officiel (avec « DeNoTa » + slogan).
- `assets/images/app_icon.png` — source de l'icône d'app (1024×1024).
- `assets/images/app_icon_foreground.png` — avant-plan pour l'icône
  adaptative Android (design recentré dans la zone de sécurité).

## Icône de l'application (Android + iOS)
Ajout de **`flutter_launcher_icons`** dans `pubspec.yaml` :
- Android : icône adaptative, fond vert `#1B5E3B`, avant-plan = l'icône.
- iOS : icône pleine, alpha retiré (requis par l'App Store).
La génération se lance avec `dart run flutter_launcher_icons` — c'est
désormais **automatique dans le CI** (nouvelle étape « Générer les icônes »).

## Logo dans l'app
- **Splash screen** : le logo officiel remplace l'ancien texte + étoile,
  posé sur le fond nuit `#0D1B2A` avec halo vert.
- **Écran de connexion** : le logo officiel remplace le texte « DeNoTa »
  (le slogan redondant a été retiré puisque le logo le contient déjà).
- Les petits logos texte des barres d'app (feed, inscription) sont
  conservés : à cette taille, le texte reste plus lisible que l'image.

## En local (si tu veux régénérer les icônes toi-même)
```bash
flutter pub get
dart run flutter_launcher_icons
```

---

# Mise à jour — Déconnexion multi-rôles + overflow admin

## Déconnexion recruteur / admin
Les dashboards recruteur et admin n'avaient **aucun bouton de déconnexion** :
un recruteur ou un admin arrivait sur son tableau de bord sans moyen visible
de se déconnecter (il fallait deviner qu'il fallait aller dans l'onglet Profil).

- Nouveau helper partagé `widgets/common/logout_action.dart` :
  `LogoutMenuButton` (engrenage → menu → déconnexion avec confirmation).
- Ajouté dans l'AppBar du **dashboard admin** et du **dashboard recruteur**.
- La déconnexion depuis l'onglet Profil (engrenage) fonctionnait déjà ;
  elle est conservée.

## Overflow des cartes de stats (admin → Vue globale)
Les 4 cartes affichaient « BOTTOM OVERFLOWED BY 11 PIXELS ».
Cause : `childAspectRatio: 1.6` rendait les cartes trop courtes pour
icône + chiffre + label. Corrigé (`1.35`, paddings et tailles ajustés,
label en ellipsis).

## Modération / validation des vidéos et statuts
Vérifié en direct sur la base : les 2 posts en attente existent, la fonction
`is_admin()` et la policy `posts_admin_all` autorisent bien l'admin à les
lire ET à les modérer. La requête du tab Modération renvoie correctement les
posts sous l'identité admin. **Le backend est fonctionnel.**

Si le tab Modération apparaît vide, c'est que l'APK installé date d'un build
antérieur : reconstruire avec cette version règle le problème. À la validation
(« Publier »), `published_at` est renseigné pour que le contenu apparaisse
aussitôt dans le feed.

---

# Nouvelle fonctionnalité — Validation des comptes par l'admin

## Principe
Certains rôles doivent être **validés par un administrateur** avant d'accéder
à la plateforme. Par défaut : **recruteur, institution, expert** (ils accèdent
à des données sensibles, dont des profils de mineurs). Les **athlètes** et
**sponsors** restent actifs immédiatement (auto-inscription).

Pour exiger aussi la validation des athlètes : ajouter `'athlete'` au tableau
`v_roles_pending` dans la migration `008_account_approval.sql`.

## Fonctionnement
1. À l'inscription, un recruteur est créé avec `status = 'pending'`.
2. Il voit un écran **« Compte en attente de validation »** (avec bouton
   « Vérifier mon statut » et déconnexion) au lieu de l'application.
3. L'admin voit le compte dans l'onglet **Utilisateurs** (les comptes en
   attente apparaissent en premier, badge orange « En attente ») avec deux
   boutons : ✓ **Valider** et ✗ **Refuser**.
4. Validé → `active`, l'utilisateur accède à l'app. Refusé → `banned`, il voit
   un écran « Compte non autorisé ».

## Côté base (migration 008, déjà appliquée)
- `handle_new_user` : attribue `pending` ou `active` selon le rôle.
- `admin_approve_user(uuid)` / `admin_reject_user(uuid)` : fonctions
  SECURITY DEFINER protégées par `is_admin()` (un non-admin ne peut pas les
  appeler — vérifié).

## Côté app
- `home_shell` charge aussi le `status` et bloque l'accès si ≠ 'active'.
- Nouvel écran `auth/account_status_screen.dart` (attente / refusé / suspendu).
- Onglet Utilisateurs admin : boutons Valider / Refuser pour les comptes en
  attente ; badges de statut colorés (Actif / En attente / Refusé / Suspendu).

## Distinction importante
- **Onglet Modération** = valide les *contenus* (vidéos, statuts, articles).
- **Onglet Utilisateurs** = valide/gère les *comptes* (personnes).

---

# Migration 009 — Correction critique modération + Security Advisor

## LE bug de la modération (enfin trouvé)
`is_admin()` faisait `SELECT ... FROM profiles` sans qualifier le schéma, et
n'avait pas de `search_path` fixe. Dans certains contextes d'appel de l'API
(search_path vide), `profiles` n'était pas résolu → **is_admin() plantait** →
la policy `posts_admin_all` ne s'appliquait pas → l'admin ne voyait AUCUN post
en attente. Le compteur « En attente : 2 » passait par un autre chemin, d'où la
contradiction (2 annoncés mais liste vide).

**Correctif** : `search_path = public` fixé sur toutes les fonctions applicatives.
Vérifié : `is_admin()` renvoie désormais `true` et la requête de modération
renvoie bien les 2 posts, même avec un search_path vide.

## Security Advisor — alertes traitées
- **60 warnings « Function Search Path Mutable »** → réglés par le même
  `ALTER FUNCTION ... SET search_path = public`.
- **Erreur « Security Definer View » (athletes_search)** → `security_invoker = true`
  (la vue respecte maintenant la RLS de l'appelant, dont le masquage des mineurs).
- **5 info « RLS Enabled No Policy »** → policies ajoutées :
  cities / countries / institutions (lecture publique), athlete_institutions et
  recruiter_profiles (lecture publique + écriture par le propriétaire).
- **spatial_ref_sys** (table système PostGIS) : laissée telle quelle
  volontairement (activer la RLS casserait les requêtes spatiales ; aucune
  donnée sensible).

Toutes ces corrections sont **déjà appliquées** sur denota-ci et consignées
dans `009_security_hardening.sql`.

---

# Correctif — Suspension accidentelle de comptes + alertes restantes

## Comptes suspendus par erreur (réactivés)
Les comptes admin et athlète s'étaient retrouvés en `suspended` (bouton de
l'onglet Utilisateurs cliqué par mégarde — il bascule active⇄suspended). Les
deux ont été **réactivés** en base. Protections ajoutées :
- L'admin **ne peut plus se suspendre lui-même** (blocage + badge « Vous » à la
  place du bouton sur sa propre ligne).
- **Confirmation obligatoire** avant de suspendre un compte.

## Security Advisor — alertes restantes
- **Public Can Execute SECURITY DEFINER** (admin_approve_user/reject) : c'est moi
  qui l'avais introduite. Corrigé : `REVOKE EXECUTE ... FROM PUBLIC, anon`,
  accès réservé à `authenticated` (ajouté à la migration 009).
- **RLS Disabled — spatial_ref_sys** : table système PostGIS, laissée telle
  quelle volontairement (aucune donnée sensible ; activer la RLS casse le géo).
- **Extension in Public** (postgis, pg_trgm) : installées dans `public` par
  défaut par Supabase. Les déplacer est risqué et non nécessaire → à ignorer.
- **Public Bucket Allows Listing** (avatars, videos) : ces buckets sont publics
  volontairement (les avatars et vidéos ont besoin d'URL publiques). Comportement
  attendu pour l'app, pas un défaut.
