terraform {
  required_version = "~>1.12"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.45.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.45.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.7.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0.0"
    }
  }

  backend "s3" {
    bucket = "your-terraform-state-bucket" # Replace with your S3 bucket name
    prefix = "your/prefix/for/state" # Replace with your desired prefix
  }
}