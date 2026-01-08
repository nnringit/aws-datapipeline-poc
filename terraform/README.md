# Terraform Infrastructure

This directory contains Terraform configuration for the AWS Data Pipeline PoC.

## Resources Created

| Resource | Name | Description |
|----------|------|-------------|
| S3 Bucket | `{account-id}-eu-west-2-datapipeline-raw` | Raw data input |
| S3 Bucket | `{account-id}-eu-west-2-datapipeline-processed` | Processed output |
| Lambda | `glue-pipeline-trigger` | S3 event trigger |
| Glue Database | `datapipeline_poc_db` | Catalog database |
| Glue Crawler | `customers-raw-crawler` | Schema discovery |
| Glue Job | `customer-data-cleansing-job` | ETL processing |
| IAM Role | `GlueDataPipelineRole` | Glue permissions |
| IAM Role | `LambdaGlueTriggerRole` | Lambda permissions |

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- IAM permissions to create the above resources

## Usage

### Initialize Terraform

```bash
cd terraform
terraform init
```

### Review Changes

```bash
terraform plan
```

### Apply Infrastructure

```bash
terraform apply
```

### Destroy Infrastructure

```bash
terraform destroy
```

## Configuration

Copy `terraform.tfvars.example` to `terraform.tfvars` to customize:

```bash
cp terraform.tfvars.example terraform.tfvars
```

## Important Notes

1. **Existing Resources**: If resources already exist from manual creation, either:
   - Import them: `terraform import aws_s3_bucket.raw {bucket-name}`
   - Or destroy manually first, then apply Terraform

2. **State Management**: For production, configure remote state:
   ```hcl
   terraform {
     backend "s3" {
       bucket = "your-terraform-state-bucket"
       key    = "datapipeline/terraform.tfstate"
       region = "eu-west-2"
     }
   }
   ```

3. **Glue Script Updates**: After modifying `src/glue/customer_data_cleansing.py`, run:
   ```bash
   terraform apply  # Updates the S3 object automatically
   ```

## File Structure

```
terraform/
├── providers.tf          # AWS provider configuration
├── variables.tf          # Input variables
├── locals.tf             # Local values and data sources
├── s3.tf                 # S3 buckets and notifications
├── iam.tf                # IAM roles and policies
├── glue.tf               # Glue database, crawler, job
├── lambda.tf             # Lambda function and permissions
├── outputs.tf            # Output values
├── terraform.tfvars.example  # Example variables file
└── README.md             # This file
```
