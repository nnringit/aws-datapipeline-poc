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
| **Input S3 Bucket** | `{account-id}-eu-west-2-datapipeline-raw` | Raw CSV files |
| **Output S3 Bucket** | `{account-id}-eu-west-2-datapipeline-processed` | Cleansed data |
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
├── infrastructure/                # Manual AWS CLI config files
│   ├── glue/                      # Glue database & crawler configs
│   ├── iam/                       # IAM policy JSON files
│   └── s3/                        # S3 notification config
├── terraform/                     # Infrastructure as Code
│   ├── providers.tf               # AWS provider config
│   ├── variables.tf               # Input variables
│   ├── s3.tf                      # S3 buckets and notifications
│   ├── iam.tf                     # IAM roles and policies
│   ├── glue.tf                    # Glue database, crawler, job
│   ├── lambda.tf                  # Lambda function
│   ├── outputs.tf                 # Output values
│   └── import.ps1                 # Import existing resources
└── src/
    ├── glue/
    │   └── customer_data_cleansing.py  # PySpark ETL script
    └── lambda/
        └── glue_trigger/
            └── handler.py              # Lambda S3 event handler
```

---

## Deployment

### Option 1: Terraform (Recommended)

Deploy all infrastructure with a single command:

```powershell
cd terraform
terraform init
terraform plan
terraform apply
```

**What gets created:**
- 2 S3 buckets with versioning, encryption, public access blocks
- 2 IAM roles with least-privilege policies
- Glue database, crawler, and ETL job
- Lambda function with S3 trigger
- S3 bucket notification

**For existing resources**, import them first:
```powershell
# Example imports (see terraform/import.ps1 for full list)
terraform import aws_s3_bucket.raw "{account-id}-eu-west-2-datapipeline-raw"
terraform import aws_glue_job.customer_cleansing "customer-data-cleansing-job"
terraform import aws_lambda_function.glue_trigger "glue-pipeline-trigger"
```

See [terraform/README.md](terraform/README.md) for complete documentation.

---

### Option 2: AWS CLI (Manual)

#### Step 1: Create S3 Buckets
```powershell
$ACCOUNT_ID = (aws sts get-caller-identity --query "Account" --output text)
aws s3 mb "s3://${ACCOUNT_ID}-eu-west-2-datapipeline-raw" --region eu-west-2
aws s3 mb "s3://${ACCOUNT_ID}-eu-west-2-datapipeline-processed" --region eu-west-2
```

#### Step 2: Create IAM Roles
```powershell
# Glue Role
aws iam create-role --role-name GlueDataPipelineRole --assume-role-policy-document file://infrastructure/iam/glue-trust-policy.json
aws iam put-role-policy --role-name GlueDataPipelineRole --policy-name GlueS3Access --policy-document file://infrastructure/iam/glue-s3-policy.json
aws iam attach-role-policy --role-name GlueDataPipelineRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole

# Lambda Role
aws iam create-role --role-name LambdaGlueTriggerRole --assume-role-policy-document file://infrastructure/iam/lambda-trust-policy.json
aws iam put-role-policy --role-name LambdaGlueTriggerRole --policy-name GlueTriggerPolicy --policy-document file://infrastructure/iam/lambda-execution-policy.json
```

#### Step 3: Create Glue Resources
```powershell
# Database
aws glue create-database --database-input file://infrastructure/glue/database-input.json --region eu-west-2

# Upload Glue script
aws s3 cp "src\glue\customer_data_cleansing.py" "s3://${ACCOUNT_ID}-eu-west-2-datapipeline-raw/scripts/" --region eu-west-2

# Create Glue job (update script location with your account ID)
aws glue create-job --name customer-data-cleansing-job --role GlueDataPipelineRole --command "Name=glueetl,ScriptLocation=s3://${ACCOUNT_ID}-eu-west-2-datapipeline-raw/scripts/customer_data_cleansing.py,PythonVersion=3" --glue-version "4.0" --number-of-workers 2 --worker-type G.1X --region eu-west-2

# Crawler
aws glue create-crawler --cli-input-json file://infrastructure/glue/crawler-config.json --region eu-west-2
```

#### Step 4: Create Lambda Function
```powershell
# Package Lambda
Compress-Archive -Path "src\lambda\glue_trigger\handler.py" -DestinationPath "lambda_function.zip" -Force

# Create function
aws lambda create-function --function-name glue-pipeline-trigger --runtime python3.12 --role "arn:aws:iam::${ACCOUNT_ID}:role/LambdaGlueTriggerRole" --handler handler.lambda_handler --zip-file fileb://lambda_function.zip --timeout 30 --memory-size 128 --environment "Variables={GLUE_JOB_NAME=customer-data-cleansing-job,ALLOWED_EXTENSIONS=.csv,ALLOWED_PREFIXES=customers/}" --region eu-west-2

# Add S3 permission
aws lambda add-permission --function-name glue-pipeline-trigger --statement-id s3-trigger --action lambda:InvokeFunction --principal s3.amazonaws.com --source-arn "arn:aws:s3:::${ACCOUNT_ID}-eu-west-2-datapipeline-raw" --source-account $ACCOUNT_ID --region eu-west-2

# Configure S3 notification
aws s3api put-bucket-notification-configuration --bucket "${ACCOUNT_ID}-eu-west-2-datapipeline-raw" --notification-configuration file://infrastructure/s3/notification-config.json --region eu-west-2

# Cleanup
Remove-Item "lambda_function.zip"
```

---

## Quick Start

### Trigger Pipeline (Automatic)
Simply upload a CSV file to the `customers/` prefix:
```powershell
aws s3 cp "data\raw\customers.csv" "s3://{account-id}-eu-west-2-datapipeline-raw/customers/" --region eu-west-2
```
The Lambda function automatically triggers the Glue job.

### Check Job Status
```powershell
aws glue get-job-runs --job-name customer-data-cleansing-job --region eu-west-2 --query "JobRuns[0].{State:JobRunState,StartedOn:StartedOn}"
```

### Download Processed Output
```powershell
aws s3 cp "s3://{account-id}-eu-west-2-datapipeline-processed/customers/" "data\processed\customers\" --recursive --region eu-west-2
```

---

## Operations

### Update Glue Script
```powershell
# Terraform: Just apply (auto-uploads)
cd terraform && terraform apply

# Manual: Upload to S3
aws s3 cp "src\glue\customer_data_cleansing.py" "s3://{account-id}-eu-west-2-datapipeline-raw/scripts/" --region eu-west-2
```

### Update Lambda Function
```powershell
# Terraform: Just apply (auto-packages)
cd terraform && terraform apply

# Manual: Package and update
Compress-Archive -Path "src\lambda\glue_trigger\handler.py" -DestinationPath "lambda_function.zip" -Force
aws lambda update-function-code --function-name glue-pipeline-trigger --zip-file fileb://lambda_function.zip --region eu-west-2
Remove-Item "lambda_function.zip"
```

### Run Glue Crawler
```powershell
aws glue start-crawler --name customers-raw-crawler --region eu-west-2
aws glue get-crawler --name customers-raw-crawler --region eu-west-2 --query "Crawler.State"
```

### Check Lambda Logs
```powershell
aws logs filter-log-events --log-group-name "/aws/lambda/glue-pipeline-trigger" --limit 10 --region eu-west-2 --query "events[*].message"
```

---

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
