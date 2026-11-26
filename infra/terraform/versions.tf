terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # L'état est stocké dans un bucket GCS privé, distinct du bucket des fichiers.
  # Décommenter une fois le bucket créé (voir README).
  # backend "gcs" {
  #   bucket = "chatisen-tfstate"
  #   prefix = "env/prod"
  # }
}
