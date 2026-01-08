# =============================================================================
# Terraform Import Script for Existing AWS Resources
# =============================================================================
# Run this script after 'terraform init' to import existing resources
# that were created manually via AWS CLI.
# =============================================================================

$ACCOUNT_ID = "795359014756"
$REGION = "eu-west-2"

Write-Host "Importing existing AWS resources into Terraform state..." -ForegroundColor Cyan
Write-Host ""

# S3 Buckets
Write-Host "Importing S3 buckets..." -ForegroundColor Yellow
terraform import aws_s3_bucket.raw "${ACCOUNT_ID}-${REGION}-datapipeline-raw"
terraform import aws_s3_bucket.processed "${ACCOUNT_ID}-${REGION}-datapipeline-processed"

# S3 Bucket configurations
Write-Host "Importing S3 bucket configurations..." -ForegroundColor Yellow
terraform import aws_s3_bucket_versioning.raw "${ACCOUNT_ID}-${REGION}-datapipeline-raw"
terraform import aws_s3_bucket_versioning.processed "${ACCOUNT_ID}-${REGION}-datapipeline-processed"
terraform import aws_s3_bucket_server_side_encryption_configuration.raw "${ACCOUNT_ID}-${REGION}-datapipeline-raw"
terraform import aws_s3_bucket_server_side_encryption_configuration.processed "${ACCOUNT_ID}-${REGION}-datapipeline-processed"
terraform import aws_s3_bucket_public_access_block.raw "${ACCOUNT_ID}-${REGION}-datapipeline-raw"
terraform import aws_s3_bucket_public_access_block.processed "${ACCOUNT_ID}-${REGION}-datapipeline-processed"

# IAM Roles
Write-Host "Importing IAM roles..." -ForegroundColor Yellow
terraform import aws_iam_role.glue GlueDataPipelineRole
terraform import aws_iam_role.lambda LambdaGlueTriggerRole

# IAM Role Policies (inline)
Write-Host "Importing IAM role policies..." -ForegroundColor Yellow
terraform import aws_iam_role_policy.glue_s3 "GlueDataPipelineRole:GlueS3AccessPolicy"
terraform import aws_iam_role_policy.lambda_glue_trigger "LambdaGlueTriggerRole:GlueTriggerPolicy"

# IAM Role Policy Attachments
Write-Host "Importing IAM policy attachments..." -ForegroundColor Yellow
terraform import aws_iam_role_policy_attachment.glue_service "GlueDataPipelineRole/arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"

# Glue Resources
Write-Host "Importing Glue resources..." -ForegroundColor Yellow
terraform import aws_glue_catalog_database.main "datapipeline_poc_db"
terraform import aws_glue_crawler.customers_raw "customers-raw-crawler"
terraform import aws_glue_job.customer_cleansing "customer-data-cleansing-job"

# Lambda Function
Write-Host "Importing Lambda function..." -ForegroundColor Yellow
terraform import aws_lambda_function.glue_trigger "glue-pipeline-trigger"

# Lambda Permission
Write-Host "Importing Lambda permission..." -ForegroundColor Yellow
terraform import aws_lambda_permission.allow_s3 "glue-pipeline-trigger/AllowS3Invoke"

# CloudWatch Log Group
Write-Host "Importing CloudWatch log group..." -ForegroundColor Yellow
terraform import aws_cloudwatch_log_group.lambda "/aws/lambda/glue-pipeline-trigger"

# S3 Bucket Notification (must be imported last after Lambda permission)
Write-Host "Importing S3 bucket notification..." -ForegroundColor Yellow
terraform import aws_s3_bucket_notification.raw_bucket_notification "${ACCOUNT_ID}-${REGION}-datapipeline-raw"

Write-Host ""
Write-Host "Import complete! Run 'terraform plan' to verify state." -ForegroundColor Green
Write-Host ""
Write-Host "Note: Some resources may show differences due to configuration drift." -ForegroundColor Yellow
Write-Host "Review the plan carefully before running 'terraform apply'." -ForegroundColor Yellow
