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
