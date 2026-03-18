# CS1 Infrastructure as Code

AWS infrastructure using Terraform: VPC, EC2, RDS, Grafana monitoring, and S3 storage.

## Prerequisites

- Terraform >= 1.5
- AWS CLI v2 configured with credentials
- Account ID and region set (see Configuration below)

## Quick Start

### 1. Clone and setup

```bash
git clone <repo-url>
cd cs1
cd main
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your desired values:
- `grafana_admin_password` (change from default)
- Other infrastructure parameters as needed

### 2. Initialize Terraform backend

The first time, you must deploy the backend infrastructure separately:

```bash
cd bootstrap
terraform init
terraform apply
```

This creates:
- S3 bucket for storing Terraform state
- DynamoDB table for state locking

The outputs will show the backend bucket name and lock table name.

### 3. Migrate root state to backend

Update `backend.hcl` with the values from bootstrap outputs, then run:

```bash
cd ../main
terraform init -migrate-state -backend-config=backend.hcl
```

### 4. Deploy main infrastructure

```bash
terraform plan
terraform apply
```

## File Structure

```
├── bootstrap/                   # Backend infrastructure (separate apply)
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── main/                        # Main environment root stack
│   ├── main.tf                  # Root module orchestration
│   ├── variables.tf             # Input variables
│   ├── outputs.tf               # Output values
│   ├── provider.tf              # AWS provider config (eu-central-1 hardcoded)
│   ├── backend.tf               # S3 backend configuration
│   ├── backend.hcl.example      # Template for backend.hcl (gitignored)
│   └── terraform.tfvars.example # Template for terraform.tfvars (create your own)
│
└── terraform/                   # Infrastructure modules
    ├── aws-vpc-main/            # Main VPC (10.0.0.0/16)
    ├── aws-vpc-spoke/           # Spoke VPC (10.1.0.0/16)
    ├── aws-ec2-1/               # Web server 1
    ├── aws-ec2-2/               # Web server 2
    ├── aws-alb/                 # Application load balancer
    ├── aws-rds/                 # PostgreSQL database
    ├── aws-monitoring/          # Prometheus + Grafana stack
    └── aws-s3/                  # App storage bucket
```

## Important Notes

- **Region**: Locked to `eu-central-1` (do not change in provider.tf)
- **State**: Stored in S3 with DynamoDB locking (multi-account safe)
- **Account Portability**: Bucket names include account ID for uniqueness across AWS accounts
- **Monitoring**: Grafana accesses Node Exporter Full dashboard via Prometheus scraping web EC2 instance node exporters at private IPs

## Monitoring

After deployment, access Grafana:

1. Get Grafana DNS from `terraform output alb_dns_name`
2. Login with credentials from `terraform.tfvars`
3. Grafana autloads Node Exporter Full dashboard showing system metrics

Prometheus is available at `http://<grafana-lb-dns>:9090`

## Cost & Cleanup

To destroy all resources:

```bash
terraform destroy
cd bootstrap
terraform destroy
```

Then manually delete the S3 backend bucket in AWS console (contains state history).

## CI/CD Deployment

For GitHub Actions / GitLab CI:

1. Add AWS credentials as repository secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION=eu-central-1`

2. Create `.github/workflows/terraform.yml` (example):
   ```yaml
   name: Terraform
   on: [push]
   jobs:
     terraform:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v3
         - uses: hashicorp/setup-terraform@v2
             - run: cd main && terraform init -backend-config=backend.hcl -backend-config="bucket=${{ secrets.TF_BACKEND_BUCKET }}" -backend-config="lock_table=${{ secrets.TF_LOCK_TABLE }}"
             - run: cd main && terraform plan
             - run: cd main && terraform apply -auto-approve
   ```

3. Add `TF_BACKEND_BUCKET` and `TF_LOCK_TABLE` as repository secrets (from bootstrap outputs)

## Troubleshooting

**Error: "Error acquiring the lease"**
- DynamoDB lock table is locked. Check if another `terraform apply` is in progress. Wait 10 seconds and retry.

**Error: "S3 bucket already exists"**
- Account ID in bucket name ensures uniqueness per account. If deploying to same account with different prefix, update `s3_bucket_name_prefix` in terraform.tfvars.

**Web exporters showing `up=0` in Prometheus**
- Check EC2 instance system logs (AWS Console > EC2 > Instances > System log) for cloud-init errors
- Ensure security group allows 9100 ingress from monitoring instance SG

## Support

For questions about Terraform, AWS, Prometheus, or Grafana, refer to:
- Terraform docs: https://www.terraform.io/docs
- AWS docs: https://docs.aws.amazon.com
- Prometheus: https://prometheus.io/docs
- Grafana: https://grafana.com/docs
