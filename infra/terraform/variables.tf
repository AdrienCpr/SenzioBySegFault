variable "project_id" {
  description = "Identifiant du projet GCP"
  type        = string
}

variable "region" {
  description = "Région GCP (Paris)"
  type        = string
  default     = "europe-west9"
}

variable "zone" {
  description = "Zone GCP des VM"
  type        = string
  default     = "europe-west9-a"
}

variable "subnet_cidr" {
  description = "Plage du sous-réseau chatisen-vpc"
  type        = string
  default     = "10.10.0.0/24"
}
