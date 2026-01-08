# =============================================================================
# Lambda Function Package
# =============================================================================

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../src/lambda/glue_trigger/handler.py"
  output_path = "${path.module}/lambda_function.zip"
}

# =============================================================================
# Lambda Function
# =============================================================================

resource "aws_lambda_function" "glue_trigger" {
  function_name    = var.lambda_function_name
  role             = aws_iam_role.lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30
  memory_size      = 128
  description      = "Triggers Glue ETL job when new CSV files are uploaded to S3"

  environment {
    variables = {
      GLUE_JOB_NAME      = var.glue_job_name
      ALLOWED_EXTENSIONS = ".csv"
      ALLOWED_PREFIXES   = local.customers_prefix
    }
  }

  depends_on = [aws_iam_role_policy.lambda_glue_trigger]
}

# =============================================================================
# Lambda Permission for S3 Trigger
# =============================================================================

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.glue_trigger.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw.arn
  source_account = local.account_id
}

# =============================================================================
# CloudWatch Log Group for Lambda
# =============================================================================

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 14
}
