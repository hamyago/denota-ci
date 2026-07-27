# DeNoTa — Backend Supabase

Les 5 fichiers de migration SQL se trouvent dans `supabase/migrations/`.
Appliquez-les **dans l'ordre** sur votre projet Supabase `denota-ci` :

1. `001_core_tables.sql` — Enums, profiles, sports, positions, institutions
2. `002_content_messaging.sql` — Posts, likes, comments, stats, messaging, notifications
3. `003_rls_policies.sql` — Row Level Security pour chaque table
4. `004_functions_triggers.sql` — Fonctions de calcul talent_score, triggers
5. `005_storage_seed.sql` — Buckets Storage, seed villes/pays

## Variables d'environnement

Copiez `.env.example` en `.env` et remplissez les valeurs de votre projet Supabase.
