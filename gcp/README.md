# GCP Terraform Infrastructure

> **🚀 Production-ready infrastructure setup for Google Cloud Platform with Kubernetes Ingress, SSL certificates, and Cloudflare DNS management**

## 📋 Overview

This Terraform configuration provides a complete infrastructure setup for deploying applications to Google Cloud Platform with:

- **GKE Ingress** with SSL termination
- **Google Certificate Manager** for wildcard SSL certificates
- **Cloudflare DNS** integration for domain management
- **Automated HTTPS redirect** and security policies
- **Multi-subdomain support** (www, api, app)

## 🏗️ Architecture

```
Internet → Cloudflare DNS → GCP Load Balancer → GKE Ingress → Kubernetes Services
                                    ↓
                            SSL Certificate Manager
                                    ↓
                               SSL Termination
```

## 📁 Project Structure

```
.
├── provider.tf                    # Provider configuration
├── versions.tf                    # Provider versions and backend
├── cloudflare.tf                  # Cloudflare DNS verification records
├── cloudflare_records.tf          # Cloudflare A records for subdomains
├── gke_ingress_service.tf         # GKE Ingress and Kubernetes manifests
├── google_certificate_manager.tf  # Google Certificate Manager resources
└── ssl_policy.tf                  # Google Cloud SSL security policy
```

## 🛠️ Prerequisites

### Required Tools
- [Terraform](https://www.terraform.io/downloads.html) ~> 1.12
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

### Required Accounts & Access
- **Google Cloud Project** with billing enabled
- **Cloudflare account** with domain management
- **AWS S3 bucket** for Terraform state storage
- **GKE cluster** already deployed and accessible

### Required Permissions
- **Google Cloud**: Project Editor or custom role with:
  - Certificate Manager Admin
  - Compute Network Admin
  - Kubernetes Engine Admin
  - DNS Administrator
- **Cloudflare**: Zone:Edit permissions for your domain

## ⚙️ Configuration

### 1. Update Backend Configuration

Edit `versions.tf`:
```hcl
backend "s3" {
  bucket = "your-terraform-state-bucket"    # ← Replace this
  prefix = "your/prefix/for/state"          # ← Replace this
}
```

### 2. Configure Provider Settings

Edit `provider.tf` with your specific values:

```hcl
locals {
  name          = "my-awesome-project"      # ← Your project name
  organization_id = "123456789012"         # ← Your GCP org ID
  billing_account = "ABCDEF-123456-789012" # ← Your billing account
  
  org_shorthand = "myorg"                  # ← Short organization name
  domain  = "example.com"                  # ← Your domain
  
  cloudflare_zone_id = "abc123def456"      # ← Cloudflare zone ID
  google_site_verification_token = "xyz123" # ← Google verification token
}
```

### 3. Required External Resources

Ensure these resources exist before applying:

#### GKE Cluster
```bash
gcloud container clusters create my-cluster \
  --zone=asia-south1-a \
  --enable-ip-alias \
  --num-nodes=3 \
  --enable-network-policy
```

#### Static IP Address
```bash
gcloud compute addresses create [org-shorthand]-[environment]-gke-ip --global
```

#### Project Module
Ensure your project module (`module.project`) is available and outputs `project_id`.

#### Google Site Verification Token
1. Go to [Google Search Console](https://search.google.com/search-console)
2. Add your domain
3. Choose "HTML tag" method
4. Extract the token from the meta tag

Add to your locals:
```hcl
locals {
  google_site_verification_token = "AbCdEfGhIjKlMnOpQrStUvWxYz1234567890"
}
```

## 🚀 Deployment

### 1. Initialize Terraform
```bash
terraform init
```

### 2. Plan Deployment
```bash
terraform plan -out=tfplan
```

### 3. Apply Configuration
```bash
terraform apply tfplan
```

### 4. Monitor Certificate Provisioning
```bash
# Check GKE managed certificate status (takes 10-15 minutes)
kubectl get managedcertificate -n production -w

# Check Certificate Manager status
gcloud certificate-manager certificates list
```

### 5. Update Kubernetes Services

Replace the placeholder values in `gke_ingress_service.tf`:
- `<KUBERNETES__FRONTEND_SERVICE_NAME>` → Your actual service name
- `<KUBERNETES__FRONTEND_SERVICE_PORT>` → Your actual service port

## 📊 Resource Overview

| File | Resources | Purpose |
|------|-----------|---------|
| `cloudflare.tf` | 2 DNS records | Domain verification for Google services |
| `cloudflare_records.tf` | 4 A records | Domain routing (root + subdomains) |
| `gke_ingress_service.tf` | 4 K8s resources | Ingress, SSL config, certificates |
| `google_certificate_manager.tf` | 4 resources | Wildcard certificate management |
| `ssl_policy.tf` | 1 policy | TLS security configuration |

## ⚠️ Common Pitfalls & Solutions

### 1. **Certificate Provisioning Failures**

**Problem**: Managed certificates stuck in "Provisioning" state

**Solutions**:
```bash
# Check DNS propagation first
dig TXT _acme-challenge.yourdomain.com

# Ensure Cloudflare proxy is OFF during certificate provisioning
# Verify DNS records are correct
kubectl describe managedcertificate -n production
```

**Common causes**:
- Cloudflare proxy enabled during verification
- DNS records not propagated (wait 24-48 hours)
- Incorrect DNS authorization records

### 2. **Ingress IP Not Assigned**

**Problem**: Ingress shows no external IP

**Solutions**:
```bash
# Check if static IP exists and is available
gcloud compute addresses list --global

# Verify ingress annotation matches IP name exactly
kubectl describe ingress -n production

# Check GKE ingress controller logs
kubectl logs -l k8s-app=gce-ingress-controller -n kube-system
```

### 3. **SSL Policy Not Applied**

**Problem**: SSL policy not enforcing TLS version

**Root cause**: SSL policy name mismatch between `ssl_policy.tf` and `gke_ingress_service.tf`

**Solution**: Ensure names match exactly:
```hcl
# In ssl_policy.tf
name = lower(join("-", [local.org_shorthand, local.environment, "ssl", "policy", "gke", "ingress"]))

# In gke_ingress_service.tf FrontendConfig
sslPolicy = lower(join("-", [local.org_shorthand, local.environment, "ssl", "policy", "gke", "ingress"]))
```

### 4. **DNS Resolution Issues**

**Problem**: Domain not resolving or resolving to wrong IP

**Debugging steps**:
```bash
# Check Cloudflare DNS settings
dig yourdomain.com
dig www.yourdomain.com

# Verify TTL settings (300 seconds recommended)
# Ensure proxy status is correct (usually OFF for verification)

# Check GCP load balancer IP
gcloud compute addresses describe your-gke-ip --global
```

### 5. **Terraform State Conflicts**

**Problem**: Multiple team members causing state locks

**Prevention**:
```bash
# Always use consistent backend configuration
# Enable state locking in S3 with DynamoDB
# Use separate workspaces for environments

terraform workspace new staging
terraform workspace new production
```

## 🔧 Advanced Configuration

### Adding New Subdomains

1. Update `cloudflare_records.tf`:
```hcl
locals {
  domain_list = [
    "www",
    "api",
    "app",
    "admin",     # ← Add new subdomain
    "dashboard"  # ← Add another
  ]
}
```

2. Update managed certificate in `gke_ingress_service.tf`:
```hcl
spec = {
  domains = [
    local.domain,
    "www.${local.domain}",
    "api.${local.domain}",
    "app.${local.domain}",
    "admin.${local.domain}",     # ← Add here
    "dashboard.${local.domain}"  # ← Add here
  ]
}
```

3. Add ingress rules for new services:
```hcl
rule {
  host = "admin.${local.domain}"
  http {
    path {
      path = "/"
      path_type = "ImplementationSpecific"
      backend {
        service {
          name = "<KUBERNETES__ADMIN_SERVICE_NAME>"
          port {
            number = "<KUBERNETES__ADMIN_SERVICE_PORT>"
          }
        }
      }
    }
  }
}
```

### Environment-Specific Deployments

Use Terraform workspaces:
```bash
# Create environments
terraform workspace new staging
terraform workspace new production

# Deploy to specific environment
terraform workspace select production
terraform apply
```

Update locals for environment-specific configuration:
```hcl
locals {
  environment = terraform.workspace
  domain = terraform.workspace == "production" ? "example.com" : "${terraform.workspace}.example.com"
  
  # Environment-specific node counts, instance types, etc.
  cluster_node_count = terraform.workspace == "production" ? 5 : 2
}
```

## 🔍 Troubleshooting Guide

### SSL Certificate Issues

```bash
# Check certificate status
kubectl get managedcertificate -n production -o yaml

# Check Certificate Manager
gcloud certificate-manager certificates describe [cert-name]

# Verify DNS authorization
gcloud certificate-manager dns-authorizations describe [auth-name]

# Check events
kubectl get events -n production --field-selector reason=FailedCreateCertificate
```

### Ingress Connectivity Issues

```bash
# Check ingress status
kubectl describe ingress -n production

# Verify backend services
kubectl get svc -n production

# Check GKE ingress controller
kubectl logs -l k8s-app=gce-ingress-controller -n kube-system --tail=100

# Test load balancer directly
curl -H "Host: yourdomain.com" http://[LOAD_BALANCER_IP]
```

### DNS Propagation Issues

```bash
# Check DNS from different locations
dig @8.8.8.8 yourdomain.com
dig @1.1.1.1 yourdomain.com
dig @208.67.222.222 yourdomain.com

# Check DNS propagation globally
# Use online tools like whatsmydns.net

# Verify Cloudflare settings
curl -X GET "https://api.cloudflare.com/client/v4/zones/[ZONE_ID]/dns_records" \
  -H "Authorization: Bearer [API_TOKEN]"
```

## 🔒 Security Best Practices

### SSL/TLS Configuration
- **Minimum TLS 1.2**: Modern SSL policy enforces secure protocols
- **HSTS Headers**: Enable HTTP Strict Transport Security
- **Regular Certificate Rotation**: Automated via Google Certificate Manager

### Network Security
- **Private GKE Cluster**: Use private nodes when possible
- **Network Policies**: Implement Kubernetes network policies
- **IP Whitelisting**: Restrict access via Cloudflare or GCP firewall rules

### Access Control
- **IAM Roles**: Use principle of least privilege
- **Service Accounts**: Dedicated service accounts for different components
- **Audit Logging**: Enable GCP audit logs for compliance

## 📈 Monitoring & Observability

### Key Metrics to Monitor

1. **Certificate Health**
   - Certificate expiration dates
   - Certificate provisioning failures
   - DNS authorization status

2. **Ingress Performance**
   - Request latency and error rates
   - Backend service health
   - Load balancer utilization

3. **DNS Resolution**
   - DNS query response times
   - DNS failure rates
   - TTL effectiveness

### Monitoring Commands

```bash
# Certificate monitoring
kubectl get managedcertificate -n production -w

# Ingress health
kubectl top nodes
kubectl get pods -n production -o wide

# DNS monitoring
watch "dig yourdomain.com +short"

# GCP load balancer metrics (use GCP Console)
# Navigate to: Network Services > Load Balancing
```

### Alerting Setup

Consider setting up alerts for:
- Certificate expiration (30 days warning)
- Ingress 5xx error rates > 1%
- DNS resolution failures
- Load balancer backend failures

## 🚨 Emergency Procedures

### Certificate Expiration Emergency

```bash
# Immediate: Check certificate status
kubectl get managedcertificate -n production

# If expired, force renewal
kubectl delete managedcertificate -n production [cert-name]
terraform apply  # Will recreate certificate

# Fallback: Use self-signed temporary certificate
kubectl create secret tls temp-tls --cert=temp.crt --key=temp.key
```

### DNS Outage Recovery

```bash
# Switch to backup DNS provider temporarily
# Update NS records at domain registrar

# Or use direct IP access
echo "[LOAD_BALANCER_IP] yourdomain.com" >> /etc/hosts
```

### Complete Infrastructure Recovery

```bash
# Backup current state
terraform state pull > backup-state.json

# Destroy and recreate (DANGER!)
terraform destroy
terraform apply

# Or selective resource recreation
terraform taint google_certificate_manager_certificate.cert_manager_root
terraform apply
```

## 📝 Maintenance Tasks

### Weekly Tasks
- Check certificate status and expiration dates
- Review DNS query logs for anomalies
- Monitor load balancer performance metrics
- Verify backup procedures

### Monthly Tasks
- Update Terraform provider versions
- Review and rotate access keys
- Audit IAM permissions
- Performance optimization review

### Quarterly Tasks
- Disaster recovery testing
- Security audit and penetration testing
- Cost optimization review
- Documentation updates

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Test changes in staging environment
4. Commit changes (`git commit -m 'Add amazing feature'`)
5. Push to branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

### Development Guidelines
- Always test in non-production first
- Update documentation for any configuration changes
- Follow Terraform best practices
- Include unit tests where applicable

## 📚 Additional Resources

### Official Documentation
- [GKE Ingress for HTTP(S) Load Balancing](https://cloud.google.com/kubernetes-engine/docs/concepts/ingress)
- [Google Certificate Manager](https://cloud.google.com/certificate-manager/docs)
- [Cloudflare API Documentation](https://developers.cloudflare.com/api/)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)

### Community Resources
- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)

### Tools & Utilities
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [DNS Propagation Checker](https://www.whatsmydns.net/)
- [SSL Certificate Checker](https://www.sslshopper.com/ssl-checker.html)

---

**⚡ Pro Tips**: 
- Always test SSL certificates in staging before production
- Keep DNS TTL low (300s) during initial setup
- Monitor certificate expiration dates proactively
- Use Terraform workspaces for environment separation

**🆘 Need Help?**: Check the troubleshooting section first, then create an issue with detailed logs and configuration details.