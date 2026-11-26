# Architecture ChatISEN - GCP, monolithe modulaire

Schéma de référence : [chatisen-gcp-monolithe-modulaire.drawio](chatisen-gcp-monolithe-modulaire.drawio)
(à ouvrir avec [draw.io](https://app.diagrams.net/) ou l'extension VS Code *Draw.io Integration*).

## Vue d'ensemble

- **Région** : Paris `europe-west9-a`, VPC `chatisen-vpc`, sous-réseau `10.10.0.0/24`.
- **VM A - Application** (`e2-standard-2`, `10.10.0.10`) en Docker Compose :
  Traefik (HTTPS/WSS, ACME) → Nginx (frontend Preact) et backend Node.js (Fastify + Socket.IO),
  Cloud SQL Auth Proxy, Prometheus / Grafana / Loki, worker Python QoS.
- **VM B - Relais média** (`e2-medium`, `10.10.0.20`) : coturn (STUN/TURN 3478, relais UDP 49160-49259).
- **Services managés** : Cloud SQL PostgreSQL (IP privée), Cloud Storage privé, Artifact Registry,
  Secret Manager, IAP (SSH), IAM.
- **Identité** : Microsoft Entra ID (SSO ISEN, OIDC code + PKCE).
- **CI/CD** : GitHub Actions (Vitest, CodeQL, ClamAV, Trivy, signature cosign) → Artifact Registry,
  Terraform, déploiement Compose via IAP après approbation.
- **DNS** : `segfault.isen.fedyna.fr` (+ staging) → IP APP, `turn.segfault.isen.fedyna.fr` → IP TURN.

## Correspondance avec le monorepo

| Composant de l'architecture        | Dossier                        |
|------------------------------------|--------------------------------|
| Frontend Nginx (Preact + Vite)     | `apps/frontend/`               |
| Backend Node.js monolithe modulaire| `apps/backend/`                |
| Worker Python QoS                  | `services/worker-qos/`         |
| Ressources GCP (Terraform)         | `infra/terraform/`             |
| Compose VM A / VM B                | `infra/compose/vm-app`, `vm-turn` |
| GitHub Actions                     | `.github/workflows/`           |
