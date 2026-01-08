variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
  default     = "datapipeline"
}

variable "glue_job_name" {
  description = "Name of the Glue ETL job"
  type        = string
  default     = "customer-data-cleansing-job"
}

variable "glue_database_name" {
  description = "Name of the Glue catalog database"
  type        = string
  default     = "datapipeline_poc_db"
}

variable "lambda_function_name" {
  description = "Name of the Lambda trigger function"
  type        = string
  default     = "glue-pipeline-trigger"
}

variable "glue_worker_type" {
  description = "Glue job worker type"
  type        = string
  default     = "G.1X"
}

variable "glue_number_of_workers" {
  description = "Number of Glue workers"
  type        = number
  default     = 2
}
