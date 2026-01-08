# =============================================================================
# Glue Catalog Database
# =============================================================================

resource "aws_glue_catalog_database" "main" {
  name        = var.glue_database_name
  description = "Database for data pipeline PoC"
}

# =============================================================================
# Glue Crawler
# =============================================================================

resource "aws_glue_crawler" "customers_raw" {
  name          = "customers-raw-crawler"
  role          = aws_iam_role.glue.arn
  database_name = aws_glue_catalog_database.main.name
  description   = "Crawler for raw customer data"
  table_prefix  = "raw_"

  s3_target {
    path = "s3://${aws_s3_bucket.raw.id}/${local.customers_prefix}"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "DELETE_FROM_DATABASE"
  }

  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING"
  }
}

# =============================================================================
# Glue ETL Job
# =============================================================================

resource "aws_glue_job" "customer_cleansing" {
  name         = var.glue_job_name
  role_arn     = aws_iam_role.glue.arn
  description  = "ETL job for customer data cleansing"
  glue_version = "4.0"

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.raw.id}/${local.scripts_prefix}customer_data_cleansing.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-disable"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-spark-ui"                  = "true"
    "--spark-event-logs-path"            = "s3://${aws_s3_bucket.raw.id}/spark-logs/"
    "--TempDir"                          = "s3://${aws_s3_bucket.raw.id}/temp/"
  }

  worker_type       = var.glue_worker_type
  number_of_workers = var.glue_number_of_workers
  timeout           = 60

  execution_property {
    max_concurrent_runs = 1
  }

  depends_on = [aws_s3_object.glue_script]
}
