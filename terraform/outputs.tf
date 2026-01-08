output "raw_bucket_name" {
  description = "Name of the raw data S3 bucket"
  value       = aws_s3_bucket.raw.id
}

output "processed_bucket_name" {
  description = "Name of the processed data S3 bucket"
  value       = aws_s3_bucket.processed.id
}

output "glue_database_name" {
  description = "Name of the Glue catalog database"
  value       = aws_glue_catalog_database.main.name
}

output "glue_crawler_name" {
  description = "Name of the Glue crawler"
  value       = aws_glue_crawler.customers_raw.name
}

output "glue_job_name" {
  description = "Name of the Glue ETL job"
  value       = aws_glue_job.customer_cleansing.name
}

output "lambda_function_name" {
  description = "Name of the Lambda trigger function"
  value       = aws_lambda_function.glue_trigger.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda trigger function"
  value       = aws_lambda_function.glue_trigger.arn
}

output "glue_role_arn" {
  description = "ARN of the Glue IAM role"
  value       = aws_iam_role.glue.arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda IAM role"
  value       = aws_iam_role.lambda.arn
}

# Convenience outputs for testing
output "upload_test_command" {
  description = "Command to upload test data and trigger the pipeline"
  value       = "aws s3 cp data/raw/customers.csv s3://${aws_s3_bucket.raw.id}/customers/ --region ${var.aws_region}"
}

output "check_job_command" {
  description = "Command to check latest Glue job run status"
  value       = "aws glue get-job-runs --job-name ${aws_glue_job.customer_cleansing.name} --region ${var.aws_region} --query \"JobRuns[0].{State:JobRunState,StartedOn:StartedOn}\""
}
