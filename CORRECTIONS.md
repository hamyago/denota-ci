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
