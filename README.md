# AWS Data Pipeline PoC

Event-driven data pipeline for customer data cleansing using S3, Lambda, Glue, and Athena in **eu-west-2**.

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  S3 Upload  │────▶│   Lambda    │────▶│  Glue ETL   │────▶│ Processed   │
│ (customers/)│     │  Trigger    │     │  (PySpark)  │     │   S3 Output │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
       │                                       │
       ▼                                       ▼
┌─────────────┐                         ┌─────────────┐
│Glue Crawler │────────────────────────▶│Glue Catalog │
└─────────────┘                         └─────────────┘
```

**Flow**: Upload CSV to `customers/` → Lambda auto-triggers → Glue job cleanses data → Output to processed bucket

## AWS Resources

| Resource | Name | Purpose |
|----------|------|---------|
| **Input S3 Bucket** | `795359014756-eu-west-2-datapipeline-raw` | Raw CSV files |
| **Output S3 Bucket** | `795359014756-eu-west-2-datapipeline-processed` | Cleansed data |
| **Lambda Function** | `glue-pipeline-trigger` | S3 event → Glue trigger |
| **Glue Database** | `datapipeline_poc_db` | Catalog metadata |
| **Glue Table** | `raw_customers` | Schema for raw data |
| **Glue Crawler** | `customers-raw-crawler` | Auto-discover schema |
| **Glue ETL Job** | `customer-data-cleansing-job` | Data transformation |
| **IAM Roles** | `GlueDataPipelineRole`, `LambdaGlueTriggerRole` | Service permissions |

## Directory Structure
```
├── .github/
│   └── copilot-instructions.md    # AI agent instructions
├── data/
│   ├── raw/
│   │   └── customers.csv          # Sample input data with quality issues
│   └── processed/
│       └── customers/             # Cleansed output (CSV)
├── infrastructure/
│   ├── glue/
│   │   ├── database-input.json    # Glue database config
│   │   └── crawler-config.json    # Crawler configuration
│   ├── iam/
│   │   ├── glue-*.json            # Glue IAM policies
│   │   └── lambda-*.json          # Lambda IAM policies
│   └── s3/
│       └── notification-config.json # S3 → Lambda trigger config
└── src/
    ├── glue/
    │   └── customer_data_cleansing.py  # PySpark ETL script
    └── lambda/
        └── glue_trigger/
            └── handler.py              # Lambda S3 event handler
```

## Quick Start

### Trigger Pipeline (Automatic)
Simply upload a CSV file to the `customers/` prefix:
```powershell
aws s3 cp "data\raw\customers.csv" "s3://795359014756-eu-west-2-datapipeline-raw/customers/" --region eu-west-2
```
The Lambda function automatically triggers the Glue job.

### Check Job Status
```powershell
# Get latest job run
aws glue get-job-runs --job-name customer-data-cleansing-job --region eu-west-2 --query "JobRuns[0].{State:JobRunState,StartedOn:StartedOn}"
```

### Download Processed Output
```powershell
aws s3 cp "s3://795359014756-eu-west-2-datapipeline-processed/customers/" "data\processed\customers\" --recursive --region eu-west-2
```

## Manual Operations

### Run Glue Crawler
```powershell
aws glue start-crawler --name customers-raw-crawler --region eu-west-2
aws glue get-crawler --name customers-raw-crawler --region eu-west-2 --query "Crawler.State"
```

### Update Glue Script
```powershell
# Must upload to S3 before running - Glue reads from S3, not local
aws s3 cp "src\glue\customer_data_cleansing.py" "s3://795359014756-eu-west-2-datapipeline-raw/scripts/" --region eu-west-2
```

### Update Lambda Function
```powershell
Compress-Archive -Path "src\lambda\glue_trigger\handler.py" -DestinationPath "lambda_function.zip" -Force
aws lambda update-function-code --function-name glue-pipeline-trigger --zip-file fileb://lambda_function.zip --region eu-west-2
Remove-Item "lambda_function.zip"
```

### Check Lambda Logs
```powershell
aws logs filter-log-events --log-group-name "/aws/lambda/glue-pipeline-trigger" --limit 10 --region eu-west-2 --query "events[*].message"
```

## Data Quality Transformations

The Glue ETL job performs these cleansing operations:

| # | Transformation | Example |
|---|----------------|---------|
| 1 | Remove duplicates | Duplicate rows eliminated |
| 2 | Standardize country | `usa` → `USA` |
| 3 | Handle NULL strings | `"NULL"`, `"N/A"` → actual null |
| 4 | Validate emails | `INVALID_EMAIL` → null |
| 5 | Fix negative amounts | `-25.00` → null |
| 6 | Trim whitespace | `"  John  "` → `"John"` |
| 7 | Resolve choice types | Handle mixed CSV data types |

## Lambda Trigger Configuration

The Lambda function (`glue-pipeline-trigger`) is configured to:
- **Trigger on**: `s3:ObjectCreated:*` events
- **Filter**: Files matching `customers/*.csv`
- **Skip**: `_SUCCESS` files, hidden files (starting with `.` or `_`)
- **Environment variables**: `GLUE_JOB_NAME`, `ALLOWED_EXTENSIONS`, `ALLOWED_PREFIXES`

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Glue job type errors | Add `ResolveChoice.apply(..., choice="cast:double")` before `toDF()` |
| Script changes not applied | Upload to S3 first - Glue reads scripts from S3 |
| Lambda not triggering | Check S3 notification config and Lambda permissions |
| IAM permission denied | Wait 10-15s for propagation, verify policies attached |

## Conventions

- **Region**: Always `eu-west-2`
- **Bucket naming**: `{account-id}-eu-west-2-datapipeline-{raw|processed}`
- **Table prefix**: `raw_` for input tables
- **Tags**: `Project: aws-datapipeline-poc`, `Environment: dev`
