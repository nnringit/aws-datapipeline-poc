# AWS Data Pipeline PoC - AI Agent Instructions

## Architecture Overview
S3 → Glue Crawler → Glue Catalog → Glue ETL Job (PySpark) → Processed S3

**Region**: Always `eu-west-2` for all AWS CLI commands.

**Key Resources**:
- Buckets: `<ACCOUNT_ID>-eu-west-2-datapipeline-raw` / `-processed`
- Glue: database `datapipeline_poc_db`, table `raw_customers`, job `customer-data-cleansing-job`

## Code Locations

| Purpose | Path |
|---------|------|
| PySpark ETL logic | `src/glue/customer_data_cleansing.py` |
| Lambda S3 trigger | `src/lambda/glue_trigger/handler.py` |
| Sample dirty data | `data/raw/customers.csv` |
| IAM policies | `infrastructure/iam/*.json` |
| Glue configs | `infrastructure/glue/*.json` |

## Critical Workflows

### Deploy Glue Script Changes
```powershell
# Must upload to S3 before running - Glue reads from S3, not local
aws s3 cp "src\glue\customer_data_cleansing.py" "s3://<ACCOUNT_ID>-eu-west-2-datapipeline-raw/scripts/" --region eu-west-2
aws glue start-job-run --job-name customer-data-cleansing-job --region eu-west-2
```

### Verify Processed Output
```powershell
aws s3 cp "s3://<ACCOUNT_ID>-eu-west-2-datapipeline-processed/customers/" "data\processed\customers\" --recursive --region eu-west-2
```

## PySpark/Glue Patterns

**CSV type coercion** - Always use `ResolveChoice` before DataFrame conversion:
```python
dynamic_frame = ResolveChoice.apply(frame=dynamic_frame, choice="cast:double")
df = dynamic_frame.toDF()
```

**NULL handling** - CSV "NULL"/"N/A" strings must be explicitly converted:
```python
df = df.withColumn("col", when(upper(trim(col("col"))) == "NULL", lit(None)).otherwise(col("col")))
```

**Single output file** - Use `.coalesce(1)` before `.write.csv()` for single-file output.

## Lambda Patterns

- Handler at `src/lambda/glue_trigger/handler.py` triggers Glue on S3 events
- Validation in `validate_file()`: checks `.csv` extension, `customers/` prefix, skips `_SUCCESS` files
- Region hardcoded: `boto3.client('glue', region_name='eu-west-2')`

## Naming Conventions

- Bucket: `{account-id}-eu-west-2-datapipeline-{raw|processed}`
- Table prefix: `raw_` for input tables
- IAM policies: `infrastructure/iam/{service}-{purpose}-policy.json`

## Common Issues

| Issue | Fix |
|-------|-----|
| Glue job type errors | Add `ResolveChoice.apply(..., choice="cast:double")` |
| Script changes not applied | Upload to S3 first (Glue reads from S3) |
| IAM permission denied | Wait 10-15s for propagation, verify `iam:PassRole` |

## Data Quality Rules (in `customer_data_cleansing.py`)
1. Remove exact duplicate rows
2. Uppercase country names
3. Convert "NULL"/"N/A" strings to null
4. Invalidate malformed emails (regex validation)
5. Null out negative purchase amounts
6. Trim whitespace from string columns
