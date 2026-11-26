# ChatISEN - Infrastructure GCP (monolithe modulaire)
# Voir docs/architecture/ pour le schéma de référence.
#
# Ressources à provisionner (tickets INFRA suivants) :
#   - VPC chatisen-vpc + sous-réseau 10.10.0.0/24 + pare-feu (APP, TURN, IAP 35.235.240.0/20)
#   - VM A "app"  : e2-standard-2, IP privée 10.10.0.10, IP publique APP réservée
#   - VM B "turn" : e2-medium,     IP privée 10.10.0.20, IP publique TURN réservée
#   - Cloud SQL PostgreSQL (IP privée via Private Services Access, PITR)
#   - Buckets Cloud Storage privés : fichiers partagés / état Terraform
#   - Artifact Registry (images signées, déploiement par digest)
#   - Secret Manager (secret HMAC TURN, secrets applicatifs) + comptes de service distincts
#   - Workload Identity Federation pour GitHub Actions

resource "google_compute_network" "vpc" {
  name                    = "chatisen-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  name          = "chatisen-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
}
