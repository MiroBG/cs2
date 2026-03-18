# Bootstrap Terraform Backend

This folder creates the remote Terraform backend resources used by the root `cs1` stack:

- S3 bucket for `terraform.tfstate`
- DynamoDB table for state locking
- GitHub OIDC provider + IAM role for GitHub Actions

## 1) Create backend resources

```bash
cd bootstrap
terraform init
terraform apply -auto-approve
```

Get outputs:

```bash
terraform output backend_bucket_name
terraform output lock_table_name
terraform output github_actions_role_arn
```

Set these GitHub repository secrets:

- `AWS_ROLE_TO_ASSUME` = `github_actions_role_arn`
- `TF_BACKEND_BUCKET` = `backend_bucket_name`
- `TF_LOCK_TABLE` = `lock_table_name`

## 2) Configure root stack backend

From repository root (`cs1`), create a backend config file from template:

```bash
cp main/backend.hcl.example main/backend.hcl
```

Edit `main/backend.hcl` and replace bucket value with `backend_bucket_name` output.

## 3) Migrate local state to S3

From the `main` environment directory:

```bash
cd main
terraform init -migrate-state -backend-config=backend.hcl
```

After migration, the root stack uses remote state in S3 with DynamoDB locking.
