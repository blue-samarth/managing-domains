locals {
  name          = "<NAME_OF_YOUR_PROJECT>"
  region        = "asia-south1"
  zone         = "asia-south1-a"
  organization_id = "<YOUR_ORG_ID>"
  billing_account = "<YOUR_BILLING_ACCOUNT_ID>"

  org_shorthand = "<ORG_SHORTHAND>"
  environment   = "prod"


  vpc_cidr = "10.0.0.0/16"                           # VPC CIDR block
  azs      = ["list", "of", "availability", "zones"] # Availability Zones

  cluster_version = "1.33" # GKE cluster version
  namespace = ["production", "staging", "development"]

  domain  = "example.com"    # Replace with your domain
  zone_id = "<YOUR_ZONE_ID>" # Google Cloud DNS zone ID for the domain

  cloudflare_zone_id = "<YOUR_CLOUDFLARE_ZONE_ID>" # Cloudflare zone ID for the domain
}