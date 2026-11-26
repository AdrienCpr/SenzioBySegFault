# ChatISEN

Messagerie temps réel pour les étudiants de l'ISEN : salons, fichiers, appels audio/vidéo (WebRTC),
connexion SSO Entra ID. Hébergée sur GCP selon une architecture **monolithe modulaire**
(voir [docs/architecture/](docs/architecture/)).

## Structure du monorepo

```
.
├── apps/
│   ├── frontend/          # Preact + Vite, servi par Nginx
│   └── backend/           # Node.js - Fastify + Socket.IO, monolithe modulaire
│       └── src/modules/   # salons, identité, fichiers, temps réel, appels
├── services/
│   └── worker-qos/        # Worker Python : qualité de service des appels
├── infra/
│   ├── terraform/         # Ressources GCP (VPC, VM, Cloud SQL, buckets, IAM…)
│   └── compose/
│       ├── vm-app/        # VM A : Traefik, frontend, backend, Cloud SQL Proxy, observabilité
│       └── vm-turn/       # VM B : coturn (relais média)
├── docs/                  # Architecture et documentation
├── docker-compose.yml     # Environnement de dev local (PostgreSQL + MinIO)
└── .github/               # CI, templates d'issues/PR, rulesets de branches
```

## Démarrage rapide

Prérequis : Node.js 22, Python 3.12+, Docker.

```bash
# Services de dev (PostgreSQL + MinIO)
docker compose up -d

# Backend  -> http://localhost:3000/health
cd apps/backend && npm install && npm run dev

# Frontend -> http://localhost:5173
cd apps/frontend && npm install && npm run dev

# Worker QoS
cd services/worker-qos
python -m venv .venv && source .venv/bin/activate   # Windows : .venv\Scripts\activate
pip install -r requirements-dev.txt && pytest
```

Tout lancer en conteneurs : `docker compose --profile app up --build`.

## Contribuer

Branches, règles de PR et conventions : voir [CONTRIBUTING.md](CONTRIBUTING.md).
