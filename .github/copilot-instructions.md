# AWS Data Pipeline PoC - AI Agent Instructions

## Quick Context
Event-driven data pipeline: S3 Upload → Lambda Trigger → Glue ETL (PySpark) → Processed S3

**Region**: Always `eu-west-2` | **IaC**: Terraform in `terraform/`

## Code Locations

| Purpose | Path |
|---------|------|
| PySpark ETL | `src/glue/customer_data_cleansing.py` |
| Lambda trigger | `src/lambda/glue_trigger/handler.py` |
| Terraform IaC | `terraform/*.tf` |
| Sample data | `data/raw/customers.csv` |

## Key Commands

```powershell
# Deploy via Terraform
cd terraform && terraform init && terraform apply

# Test pipeline (upload triggers Lambda → Glue)
aws s3 cp "data\raw\customers.csv" "s3://{account-id}-eu-west-2-datapipeline-raw/customers/" --region eu-west-2

# Check job status
aws glue get-job-runs --job-name customer-data-cleansing-job --region eu-west-2 --query "JobRuns[0].JobRunState"
```

## PySpark Patterns

```python
# Always resolve types before toDF()
dynamic_frame = ResolveChoice.apply(frame=dynamic_frame, choice="cast:double")

# Handle CSV "NULL" strings
df = df.withColumn("col", when(upper(trim(col("col"))) == "NULL", lit(None)).otherwise(col("col")))

# Single output file
df.coalesce(1).write.mode("overwrite").option("header", "true").csv(OUTPUT_PATH)
```

## Data Quality Rules
1. Remove duplicates | 2. Uppercase countries | 3. Convert "NULL"/"N/A" → null
4. Validate emails (regex) | 5. Null negative amounts | 6. Trim whitespace

## Naming Conventions
- Buckets: `{account-id}-eu-west-2-datapipeline-{raw|processed}`
- Glue: database `datapipeline_poc_db`, job `customer-data-cleansing-job`
- IAM: `GlueDataPipelineRole`, `LambdaGlueTriggerRole`

## Common Issues

| Issue | Fix |
|-------|-----|
| Type errors in Glue | Add `ResolveChoice.apply(..., choice="cast:double")` |
| Script not updated | Upload to S3 or run `terraform apply` |
| Lambda not triggering | Check S3 notification and Lambda permission |

---

## Replication Prompt

Use this prompt to recreate this entire setup from scratch:

```
I want to build an event-driven AWS data pipeline for CSV data cleansing with the following requirements:

**Architecture:**
- S3 bucket receives raw CSV files in a `customers/` prefix
- Lambda function triggers automatically on S3 upload
- AWS Glue ETL job (PySpark) cleanses the data
- Processed output written to a separate S3 bucket
- Region: eu-west-2

**Data Quality Rules:**
1. Remove exact duplicate rows
2. Standardize country names to uppercase
3. Convert string "NULL" and "N/A" values to actual nulls
4. Validate email format with regex, null invalid emails
5. Set negative purchase amounts to null
6. Trim whitespace from all string columns
7. Handle mixed data types from CSV using ResolveChoice

**Infrastructure Requirements:**
1. Two S3 buckets: raw (input) and processed (output)
2. IAM roles for Glue and Lambda with least-privilege policies
3. Glue catalog database and optional crawler
4. Glue ETL job reading directly from S3 (not catalog) to avoid race conditions
5. Lambda function with S3 event trigger (filter: customers/*.csv)
6. S3 bucket notification configuration

**Deliverables:**
1. PySpark ETL script for Glue
2. Python Lambda handler for S3 trigger
3. Terraform IaC for all infrastructure
4. Sample dirty CSV data for testing
5. README with deployment instructions (both Terraform and manual AWS CLI)

**Technical Notes:**
- Glue reads scripts from S3, not local - must upload before running
- Use ResolveChoice.apply() before toDF() to handle CSV type ambiguity
- Lambda should skip _SUCCESS files and hidden files
- Use coalesce(1) for single output file
```

This prompt will guide an AI agent to build a complete, production-ready data pipeline matching this implementation.

## Data Quality Rules (in `customer_data_cleansing.py`)
1. Remove exact duplicate rows
2. Uppercase country names
3. Convert "NULL"/"N/A" strings to null
4. Invalidate malformed emails (regex validation)
5. Null out negative purchase amounts
6. Trim whitespace from string columns
