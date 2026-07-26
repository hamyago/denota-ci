# DeNoTa CI — Backend Supabase
## Guide d'installation pas à pas

---

## 📋 Prérequis
- Compte Supabase créé sur app.supabase.com
- Projet `denota-ci` créé (région : West EU Paris)
- Node.js 18+ installé
- VS Code installé

---

## 🚀 Étape 1 — Récupérer tes clés Supabase

1. Va sur **app.supabase.com** → ton projet `denota-ci`
2. Dans le menu gauche : **Settings → API**
3. Copie ces 3 valeurs dans un fichier `.env` :

```env
SUPABASE_URL=https://XXXXXXXX.supabase.co
SUPABASE_ANON_KEY=eyJhbGci...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGci...
```

⚠️ **Ne commit JAMAIS le fichier .env sur GitHub**

---

## 🗄️ Étape 2 — Exécuter les migrations SQL

Va dans **Supabase → SQL Editor** et exécute les fichiers dans cet ordre :

### Migration 001 — Tables principales
Copie-colle le contenu de : `supabase/migrations/001_core_tables.sql`
→ Clique **Run**

### Migration 002 — Contenus & Messagerie
Copie-colle le contenu de : `supabase/migrations/002_content_messaging.sql`
→ Clique **Run**

### Migration 003 — Sécurité RLS
Copie-colle le contenu de : `supabase/migrations/003_rls_policies.sql`
→ Clique **Run**

### Migration 004 — Fonctions & Triggers
Copie-colle le contenu de : `supabase/migrations/004_functions_triggers.sql`
→ Clique **Run**

### Migration 005 — Storage & Données initiales
Copie-colle le contenu de : `supabase/migrations/005_storage_seed.sql`
→ Clique **Run**

---

## ✅ Étape 3 — Vérifier l'installation

Dans Supabase → **Table Editor**, tu dois voir ces tables :
- ✅ profiles
- ✅ athlete_profiles
- ✅ institutions
- ✅ recruiter_profiles
- ✅ posts
- ✅ athlete_stats
- ✅ expert_ratings
- ✅ conversations
- ✅ messages
- ✅ notifications
- ✅ sports (avec 20 sports pré-remplis)
- ✅ positions
- ✅ countries
- ✅ cities

Dans **Storage**, tu dois voir ces buckets :
- ✅ avatars
- ✅ banners
- ✅ videos
- ✅ posts
- ✅ kyc-documents
- ✅ institutions

---

## 🔧 Étape 4 — Configuration Auth Supabase

Dans **Authentication → Settings** :

1. **Email Auth** → Activé ✅
2. **Phone Auth** → Activé ✅ (via Termii ou Twilio)
3. **Site URL** → `http://localhost:3000` (pour le dev)
4. **Redirect URLs** → Ajouter `io.denota.app://login-callback`

### SMS Provider (Termii — Côte d'Ivoire)
Dans **Authentication → Settings → SMS** :
- Provider: **Twilio** (en attendant support Termii natif)
- Ou utiliser Edge Function personnalisée pour Termii

---

## 📱 Étape 5 — Prochaine étape : App Flutter

Structure du projet Flutter qui va être générée :
```
denota_flutter/
├── lib/
│   ├── core/           ← constantes, thème, routes
│   ├── data/           ← repositories, datasources
│   ├── domain/         ← modèles, use cases
│   ├── presentation/   ← écrans, widgets, BLoC
│   └── main.dart
├── assets/
│   ├── images/
│   └── fonts/
└── pubspec.yaml
```

---

## 🏗️ Architecture finale DeNoTa

```
┌─────────────────────────────────────────┐
│          App Flutter (Mobile)            │
│    iOS & Android — Clean Architecture   │
└──────────────────┬──────────────────────┘
                   │ HTTPS / Realtime WS
┌──────────────────▼──────────────────────┐
│              Supabase                    │
│  ┌─────────┐ ┌─────────┐ ┌──────────┐  │
│  │ PostGres│ │  Auth   │ │ Storage  │  │
│  │   + RLS │ │  + KYC  │ │  CDN    │  │
│  └─────────┘ └─────────┘ └──────────┘  │
│  ┌─────────┐ ┌─────────────────────┐   │
│  │Realtime │ │   Edge Functions    │   │
│  │ (socket)│ │ (logique serveur)   │   │
│  └─────────┘ └─────────────────────┘   │
└──────────────────┬──────────────────────┘
                   │
        ┌──────────┴──────────┐
        │                     │
┌───────▼──────┐    ┌─────────▼────────┐
│  Firebase    │    │  Cloudflare      │
│  FCM (Push) │    │  Stream (Video)  │
└──────────────┘    └──────────────────┘
```

---

## 📞 Support

En cas de problème sur une migration :
1. Va dans **Supabase → SQL Editor → Logs**
2. Lis le message d'erreur
3. Partage-le et on corrige ensemble
