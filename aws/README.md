# 🛡️ AWS ACM + Cloudflare + ALB Ingress for Custom Domains

A production-ready Terraform configuration that provisions SSL certificates via AWS ACM, manages DNS through Cloudflare, and routes traffic using AWS Application Load Balancer (ALB) with Kubernetes Ingress for your custom domain and subdomains.

## 🏗️ Architecture Overview

```
Internet → Cloudflare DNS → AWS ALB → Kubernetes Ingress → Backend Services
                ↓
           SSL/TLS Termination (ACM Certificate)
```

**Key Components:**
- **AWS ACM**: SSL/TLS certificate provisioning and management
- **Cloudflare**: DNS management and optional CDN/proxy features
- **AWS ALB**: Layer 7 load balancer with SSL termination
- **Kubernetes Ingress**: Traffic routing to backend services
- **Route 53**: Optional DNS validation (using Cloudflare instead)

---

## 📋 Prerequisites

### Required Tools
- **Terraform** ~> 1.12
- **kubectl** >= 1.24
- **AWS CLI** >= 2.0 (configured)
- **Helm** >= 3.0 (for additional chart deployments)
- **Access to**:
  - AWS account with EKS cluster
  - Cloudflare account with domain management
  - Kubernetes cluster with AWS Load Balancer Controller installed

### Required AWS Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "acm:*",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcs",
        "ec2:CreateTags",
        "elasticloadbalancing:*",
        "sts:AssumeRole"
      ],
      "Resource": "*"
    }
  ]
}
```

### Required Cloudflare Permissions
- **Zone:Edit** for DNS record management
- **Zone:Read** for zone information

---

## 🔐 Environment Setup

### Secrets Configuration
Set these environment variables before running `terraform apply`:

```bash
# AWS Credentials
export AWS_ACCESS_KEY_ID="your-aws-access-key"
export AWS_SECRET_ACCESS_KEY="your-aws-secret-key"
export AWS_DEFAULT_REGION="asia-south1"

# Cloudflare API Token
export CLOUDFLARE_API_TOKEN="your-cloudflare-token"

# Optional: AWS Role ARN for cross-account access
export TF_VAR_aws_role_arn="arn:aws:iam::ACCOUNT:role/TerraformRole"
```

### Local Variables
Create a `locals.tf` file or update your existing one:

```hcl
locals {
  name          = "your-project-name"           # Replace with your project name
  region        = "asia-south1"                 # AWS region
  org_shorthand = "your-org"                    # Organization shorthand
  environment   = "prod"                        # Environment (prod/staging/dev)

  vpc_cidr = "10.0.0.0/16"                                        # VPC CIDR block
  azs      = ["asia-south1-a", "asia-south1-b", "asia-south1-c"]  # Availability Zones

  cluster_version = "1.33"                      # EKS cluster version

  domain  = "example.com"                       # Replace with your domain
  zone_id = "your-route53-zone-id"             # Route53 zone ID (if using)

  cloudflare_zone_id = "your-cloudflare-zone-id" # Cloudflare zone ID
  
  # S3 backend configuration
  state_bucket = "your-terraform-state-bucket"   # S3 bucket for Terraform state
}
```

---

## 📁 Project Structure

```
.
├── acm_service.tf                      # ACM certificate with DNS validation  
├── cloudflare_dns_records.tf          # DNS validation records for ACM
├── cloudflare_dns_records_services.tf # Domain and subdomain CNAME records
├── kubernetes_ingress_service.tf      # ALB-backed Ingress configuration
├── provider.tf                        # AWS, Cloudflare, Kubernetes, Helm providers
├── versions.tf                        # Terraform and provider version constraints
└── README.md                          # This file
```

### Provider Versions
```hcl
terraform {
  required_version = "~> 1.12"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.5.0"
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
    bucket = 
    key    = "terraform/state/handling-domains/terraform.tfstate"
    region = local.region
  }
}
```

---

## 🎯 What This Configuration Provisions

### 🔒 SSL Certificate (ACM)
- **Primary domain**: `example.com`
- **Subdomains**: `www.example.com`, `api.example.com`, `app.example.com`
- **Validation**: DNS-based through Cloudflare
- **Renewal**: Automatic via AWS ACM

### 🌐 DNS Records (Cloudflare)
- **Validation records**: For ACM certificate verification
- **CAA records**: Authorize AWS ACM for certificate issuance
- **CNAME records**: Route traffic from domain/subdomains to ALB
- **TTL**: 300 seconds for faster propagation

### ⚖️ Load Balancer (AWS ALB)
- **Scheme**: Internet-facing
- **Protocol**: HTTP (80) → HTTPS (443) redirect
- **SSL termination**: At load balancer level
- **Health checks**: Configurable intervals and thresholds
- **Target type**: IP mode for EKS pods

### 🚦 Ingress Configuration
- **HTTP to HTTPS redirect**: Automatic 301 redirects
- **www canonicalization**: `example.com` → `www.example.com`
- **Path-based routing**: Support for multiple backend services
- **Sticky sessions**: Enabled with 24-hour cookie duration

---

## 🚀 Deployment Guide

### Step 1: Initialize Terraform
```bash
terraform init
```

### Step 2: Plan and Review
```bash
terraform plan
```

### Step 3: First Apply (Certificate Creation)
```bash
terraform apply
```

**Expected State After First Apply:**
- ✅ ACM certificate created (status: `PENDING_VALIDATION`)
- ✅ DNS validation records created in Cloudflare
- ✅ CAA records configured
- ⏳ Ingress may not have ALB hostname yet
- ⏳ Service DNS records pending ALB creation

### Step 4: Wait for Certificate Validation
```bash
# Check certificate status
aws acm describe-certificate --certificate-arn $(terraform output -raw certificate_arn) --region asia-south1

# Wait for status to change to "ISSUED" (usually 2-10 minutes)
```

### Step 5: Second Apply (Complete Setup)
```bash
terraform apply
```

**Expected State After Second Apply:**
- ✅ ACM certificate status: `ISSUED`
- ✅ ALB created and healthy
- ✅ Ingress has valid ALB hostname
- ✅ All DNS records pointing to ALB
- ✅ HTTPS traffic flowing correctly

---

## 🔧 Configuration Details

### ACM Certificate Module
```hcl
module "acm_service" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 5.1.0"

  domain_name               = local.domain
  zone_id                  = local.zone_id
  subject_alternative_names = [
    "www.${local.domain}",
    "api.${local.domain}",
    "app.${local.domain}"
  ]
  
  create_route53_records   = false  # Using Cloudflare instead
  validation_method        = "DNS"
  validation_record_fqdns  = cloudflare_dns_record.dns_record_validation[*].name
}
```

### Ingress Annotations Explained
```yaml
kubernetes.io/ingress.class: "alb"                    # Use AWS Load Balancer Controller
alb.ingress.kubernetes.io/scheme: "internet-facing"   # Public ALB
alb.ingress.kubernetes.io/certificate-arn: "..."      # Bind ACM certificate
alb.ingress.kubernetes.io/backend-protocol: "HTTPS"   # Backend communication
alb.ingress.kubernetes.io/target-type: "ip"          # Direct pod targeting
alb.ingress.kubernetes.io/subnets: "subnet-xxx,..."  # Specific subnet placement
```

### Traffic Flow Configuration
1. **HTTP → HTTPS Redirect**: All port 80 traffic redirected to 443
2. **Root Domain Redirect**: `example.com` → `www.example.com`
3. **Subdomain Routing**:
   - `www.example.com` → Frontend service
   - `api.example.com` → API service
   - `app.example.com` → Application service

---

## 🧪 Verification & Testing

### 1. Certificate Validation
```bash
# Check ACM certificate status
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw certificate_arn) \
  --region asia-south1 \
  --query 'Certificate.Status'

# Expected output: "ISSUED"
```

### 2. DNS Resolution
```bash
# Test DNS resolution
dig example.com +short
dig www.example.com +short
dig api.example.com +short

# All should return the same ALB hostname
```

### 3. SSL Certificate Validation
```bash
# Test SSL certificate
openssl s_client -connect example.com:443 -servername example.com < /dev/null 2>/dev/null | openssl x509 -noout -dates

# Check certificate chain
curl -vI https://example.com
```

### 4. HTTP to HTTPS Redirect
```bash
# Test automatic redirect
curl -I http://example.com
# Expected: HTTP/1.1 301 Moved Permanently
# Location: https://example.com

curl -I http://www.example.com
# Expected: HTTP/1.1 301 Moved Permanently
# Location: https://www.example.com
```

### 5. Load Balancer Health
```bash
# Check ALB status
aws elbv2 describe-load-balancers \
  --names $(terraform output -raw load_balancer_name) \
  --query 'LoadBalancers[0].State'

# Expected output: {"Code": "active"}
```

### 6. End-to-End Testing
```bash
# Test all domains
for subdomain in "" "www" "api" "app"; do
  if [ -z "$subdomain" ]; then
    url="https://example.com"
  else
    url="https://$subdomain.example.com"
  fi
  
  echo "Testing $url"
  curl -s -o /dev/null -w "Status: %{http_code}, Time: %{time_total}s\n" "$url"
done
```

---

## 🚨 Troubleshooting

### Common Issues and Solutions

#### Certificate Stuck in `PENDING_VALIDATION`
**Symptoms:** ACM certificate doesn't validate after 10+ minutes
```bash
# Check DNS validation records
dig _acme-challenge.example.com TXT +short

# Verify Cloudflare DNS records
terraform state show 'cloudflare_dns_record.dns_record_validation[0]'
```
**Solutions:**
- Ensure DNS records are not proxied (orange cloud off in Cloudflare)
- Verify Cloudflare API token has DNS edit permissions
- Check for conflicting DNS records

#### ALB Not Created or Unhealthy
**Symptoms:** Ingress doesn't get LoadBalancer hostname
```bash
# Check ingress status
kubectl describe ingress $(terraform output -raw ingress_name) -n $(terraform output -raw namespace)

# Check AWS Load Balancer Controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```
**Solutions:**
- Verify AWS Load Balancer Controller is installed and running
- Check IAM permissions for the controller service account
- Ensure subnets are properly tagged for ALB discovery

#### DNS Records Not Resolving
**Symptoms:** Domain doesn't resolve to ALB hostname
```bash
# Check DNS propagation
dig example.com @8.8.8.8 +short
dig example.com @1.1.1.1 +short
```
**Solutions:**
- Wait for DNS propagation (up to 48 hours globally)
- Verify Cloudflare DNS records are correctly configured
- Check if Cloudflare proxy is interfering (should be DNS-only)

#### SSL Handshake Failures
**Symptoms:** Browser shows certificate errors
```bash
# Test SSL connection
openssl s_client -connect example.com:443 -servername example.com
```
**Solutions:**
- Ensure certificate includes all required SANs
- Verify ALB listener is configured for HTTPS on port 443
- Check certificate is properly attached to ALB

#### Backend Service Connection Issues
**Symptoms:** 502 Bad Gateway or connection timeouts
```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)

# Check pod status
kubectl get pods -n $(terraform output -raw namespace) -o wide
```
**Solutions:**
- Verify backend services are running and healthy
- Check ingress path configurations
- Ensure security groups allow traffic between ALB and pods

---

## 🔄 Maintenance & Updates

### Certificate Renewal
AWS ACM automatically renews certificates 60 days before expiration. No manual intervention required.

### Updating Subdomains
To add new subdomains:
1. Add to `subject_alternative_names` in ACM module
2. Add to `local.domain_list` for DNS records
3. Update ingress rules for new paths
4. Run `terraform apply`

### Changing Domain
1. Update `domain` variable in `terraform.tfvars`
2. Update Cloudflare zone configuration
3. Run `terraform plan` to review changes
4. Run `terraform apply`

### Monitoring Recommendations
- **CloudWatch Alarms**: Monitor ALB target health and request count
- **Route 53 Health Checks**: Monitor endpoint availability
- **Certificate Expiration**: Set up ACM certificate expiration notifications

---

## 📊 Outputs

After successful deployment, Terraform provides these outputs:

```bash
# Get important resource information
terraform output certificate_arn          # ACM certificate ARN
terraform output load_balancer_dns_name    # ALB DNS hostname
terraform output load_balancer_zone_id     # ALB hosted zone ID
terraform output ingress_name              # Kubernetes ingress name
terraform output cloudflare_records        # Created DNS records
```

---

## 🧹 Cleanup

To destroy all resources:

```bash
# Remove all resources (in reverse dependency order)
terraform destroy

# Verify cleanup
aws acm list-certificates --region asia-south1
aws elbv2 describe-load-balancers
```

**⚠️ Warning:** This will permanently delete all SSL certificates, load balancers, and DNS records. Ensure you have backups if needed.

---

## 📚 Additional Resources

- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [AWS ACM User Guide](https://docs.aws.amazon.com/acm/)
- [Cloudflare API Documentation](https://developers.cloudflare.com/api/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Cloudflare Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)

---

## 🆘 Support

If you encounter issues:

1. **Check the troubleshooting section** above
2. **Review Terraform state** with `terraform show`
3. **Validate configuration** with `terraform validate`
4. **Enable debug logging** with `TF_LOG=DEBUG terraform apply`
5. **Check AWS/Cloudflare service status** pages

For persistent issues, ensure all prerequisites are met and consider consulting the official documentation for each service.

---

## 🎉 You're All Set!

Your domain is now configured with:
- ✅ Valid SSL certificate from AWS ACM
- ✅ DNS management through Cloudflare
- ✅ High-availability load balancing via AWS ALB
- ✅ Automatic HTTP to HTTPS redirects
- ✅ Production-ready security configurations

Your applications are now accessible at:
- `https://example.com` (redirects to www)
- `https://www.example.com` (main site)
- `https://api.example.com` (API endpoints)
- `https://app.example.com` (application interface)