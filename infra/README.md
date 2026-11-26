# Infra

- `terraform/` : ressources GCP. Pour l'instant seul le VPC et le sous-réseau sont déclarés ;
  la liste des ressources à venir est en tête de `main.tf`.
  ```bash
  cd infra/terraform
  cp terraform.tfvars.example terraform.tfvars   # non commité
  terraform init -backend=false && terraform validate
  ```
  L'état distant (bucket GCS privé) est à activer dans `versions.tf` une fois le bucket créé.
- `compose/vm-app/` : stack de la VM A (Traefik, frontend, backend, Cloud SQL Proxy, observabilité, worker QoS).
- `compose/vm-turn/` : stack de la VM B (coturn).

Chaque dossier Compose a un `.env.example` ; le vrai `.env` est généré au déploiement
à partir de Secret Manager et n'est jamais commité.
