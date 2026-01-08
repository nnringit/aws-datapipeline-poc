data "aws_caller_identity" "current" {}

locals {
  account_id         = data.aws_caller_identity.current.account_id
  raw_bucket_name    = "${local.account_id}-${var.aws_region}-${var.project_name}-raw"
  processed_bucket_name = "${local.account_id}-${var.aws_region}-${var.project_name}-processed"
  scripts_prefix     = "scripts/"
  customers_prefix   = "customers/"
}
