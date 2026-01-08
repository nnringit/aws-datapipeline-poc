# AWS Data Pipeline PoC - Reference Documentation

## Project Overview
AWS data pipeline demonstrating data ingestion, transformation, and cleansing using S3, Glue, and Athena in the **eu-west-2** region.

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Raw S3 Bucket │────▶│   Glue Crawler  │────▶│  Glue Catalog   │
│  (CSV input)    │     │                 │     │  (raw_customers)│
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ Processed Bucket│◀────│  Glue ETL Job   │◀────│  Data Cleansing │
│  (CSV output)   │     │  (PySpark)      │     │  Transformations│
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## AWS Resources

| Resource | Name | Purpose |
|----------|------|---------|
| **Input S3 Bucket** | `795359014756-eu-west-2-datapipeline-raw` | Store raw CSV files |
| **Output S3 Bucket** | `795359014756-eu-west-2-datapipeline-processed` | Store cleansed data |
| **Glue Database** | `datapipeline_poc_db` | Catalog metadata |
| **Glue Table** | `raw_customers` | Schema for raw data |
| **Glue Crawler** | `customers-raw-crawler` | Auto-discover schema |
| **Glue ETL Job** | `customer-data-cleansing-job` | Data transformation |
| **IAM Role** | `GlueDataPipelineRole` | Glue service permissions |

## Directory Structure
```
├── .github/
│   └── copilot-instructions.md    # This documentation
├── data/
│   ├── raw/
│   │   └── customers.csv          # Sample input data with quality issues
│   └── processed/
│       └── customers/             # Cleansed output (CSV)
├── infrastructure/
│   ├── glue/
│   │   ├── database-input.json    # Glue database config
│   │   └── crawler-config.json    # Crawler configuration
│   └── iam/
│       ├── datapipeline-user-policy.json  # User permissions
│       ├── glue-trust-policy.json         # Role trust policy
│       └── glue-s3-policy.json            # S3 access for Glue
└── src/
    └── glue/
        └── customer_data_cleansing.py     # PySpark ETL script
```

## Common Commands

### Check AWS Identity
```powershell
aws sts get-caller-identity
```

### Run Glue Crawler
```powershell
aws glue start-crawler --name customers-raw-crawler --region eu-west-2
aws glue get-crawler --name customers-raw-crawler --region eu-west-2 --query "Crawler.State"
```

### Run Glue ETL Job
```powershell
# Upload script changes first
aws s3 cp "src\glue\customer_data_cleansing.py" "s3://795359014756-eu-west-2-datapipeline-raw/scripts/" --region eu-west-2

# Start job
aws glue start-job-run --job-name customer-data-cleansing-job --region eu-west-2

# Check status (replace JOB_RUN_ID)
aws glue get-job-run --job-name customer-data-cleansing-job --run-id <JOB_RUN_ID> --region eu-west-2 --query "JobRun.JobRunState"
```

### S3 Operations
```powershell
# Upload raw data
aws s3 cp "data\raw\customers.csv" "s3://795359014756-eu-west-2-datapipeline-raw/customers/" --region eu-west-2

# Download processed data
aws s3 cp "s3://795359014756-eu-west-2-datapipeline-processed/customers/" "data\processed\customers\" --recursive --region eu-west-2

# List processed files
aws s3 ls "s3://795359014756-eu-west-2-datapipeline-processed/customers/" --region eu-west-2
```

## Data Quality Transformations

The Glue ETL job (`customer_data_cleansing.py`) performs:

1. **Remove duplicates** - Exact duplicate rows removed
2. **Standardize country** - Uppercase all country names
3. **Handle NULL strings** - Convert "NULL"/"N/A" to actual nulls
4. **Validate emails** - Regex validation, invalid emails set to null
5. **Fix negative amounts** - Negative purchase amounts set to null
6. **Trim whitespace** - Clean string column values
7. **Resolve choice types** - Handle mixed data types from CSV

## IAM Permissions Required

User needs these permissions:
- `glue:*` - Full Glue access
- `s3:*` on datapipeline buckets
- `iam:PassRole` for Glue role
- `athena:*` for querying
- `logs:*` for CloudWatch

## Conventions

- **Region**: Always use `eu-west-2`
- **Bucket naming**: `{account-id}-{region}-datapipeline-{purpose}`
- **Glue scripts**: Store in `s3://.../scripts/` folder
- **Table prefix**: `raw_` for input tables, `processed_` for output
- **Tags**: `Project: aws-datapipeline-poc`, `Environment: dev`

## Troubleshooting

### Glue Job Fails with Type Errors
Use `ResolveChoice.apply()` to handle mixed types in CSV:
```python
dynamic_frame = ResolveChoice.apply(frame=dynamic_frame, choice="cast:double")
```

### IAM Permission Denied
1. Check policy is attached: `aws iam list-user-policies --user-name <user>`
2. Wait 10-15 seconds for propagation
3. Try attaching AWS managed policy: `AWSGlueConsoleFullAccess`

### AWS CLI Not Found
Add to PATH: `$env:Path += ";C:\Program Files\Amazon\AWSCLIV2"`
