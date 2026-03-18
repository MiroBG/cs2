output "backend_bucket_name" {
  value = aws_s3_bucket.tfstate.bucket
}

output "backend_bucket_arn" {
  value = aws_s3_bucket.tfstate.arn
}

output "lock_table_name" {
  value = aws_dynamodb_table.tf_lock.name
}

output "github_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}
