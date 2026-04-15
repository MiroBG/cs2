variable "region" {
  description = "AWS region for backend resources"
  type        = string
  default     = "eu-central-1"
}

variable "backend_bucket_prefix" {
  description = "Prefix used when deriving the tfstate bucket name"
  type        = string
  default     = "cs1-tfstate"
}

variable "backend_state_key" {
  description = "Remote state key used by the Terraform backend"
  type        = string
  default     = "cs1/terraform.tfstate"
}

variable "backend_bucket_name" {
  description = "Optional explicit tfstate bucket name (must be globally unique)"
  type        = string
  default     = ""
}

variable "lock_table_name" {
  description = "DynamoDB table name used for Terraform state locking"
  type        = string
  default     = "cs1-terraform-locks"
}

variable "tags" {
  description = "Tags applied to backend resources"
  type        = map(string)
  default = {
    Project = "cs1"
  }
}

variable "github_repository" {
  description = "GitHub repository in owner/repo format allowed to assume the OIDC role"
  type        = string
  default     = "MiroBG/cs1"
}

variable "github_branch" {
  description = "GitHub branch allowed to assume the OIDC role"
  type        = string
  default     = "main"
}

variable "github_actions_role_name" {
  description = "IAM role name used by GitHub Actions via OIDC"
  type        = string
  default     = "github-actions-terraform-ci"
}

variable "github_attach_admin_access" {
  description = "Attach AdministratorAccess to the GitHub Actions role (set false to use least-privilege custom policies)"
  type        = bool
  default     = true
}
