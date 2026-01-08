import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import col, upper, when, regexp_extract, trim, lit
from pyspark.sql.types import DoubleType

# Initialize Glue context
args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Configuration
INPUT_DATABASE = "datapipeline_poc_db"
INPUT_TABLE = "raw_customers"
OUTPUT_PATH = "s3://795359014756-eu-west-2-datapipeline-processed/customers/"

print("=== Starting Data Cleansing Job ===")

# Read data from Glue catalog
print("Reading data from Glue catalog...")
dynamic_frame = glueContext.create_dynamic_frame.from_catalog(
    database=INPUT_DATABASE,
    table_name=INPUT_TABLE,
    transformation_ctx="datasource0"
)

# Resolve any choice types (e.g., purchase_amount could be string or double)
print("Resolving choice types...")
dynamic_frame = ResolveChoice.apply(
    frame=dynamic_frame,
    choice="cast:double",
    transformation_ctx="resolvechoice"
)

# Convert to Spark DataFrame for easier transformations
df = dynamic_frame.toDF()
print(f"Initial row count: {df.count()}")

# === DATA QUALITY TRANSFORMATIONS ===

# 1. Remove exact duplicates
print("Removing duplicates...")
df_cleaned = df.dropDuplicates()
print(f"After removing duplicates: {df_cleaned.count()}")

# 2. Standardize country names to uppercase
print("Standardizing country names...")
df_cleaned = df_cleaned.withColumn("country", upper(trim(col("country"))))

# 3. Fix "NULL" string values - convert to actual null (only for string columns)
print("Fixing string NULL values...")
string_cols_for_null_fix = ["first_name", "last_name", "email", "phone", "signup_date", "country"]
for column in string_cols_for_null_fix:
    if column in df_cleaned.columns:
        df_cleaned = df_cleaned.withColumn(
            column,
            when(upper(trim(col(column))) == "NULL", lit(None))
            .when(upper(trim(col(column))) == "N/A", lit(None))
            .otherwise(col(column))
        )

# 4. Validate email format using regex
print("Validating email addresses...")
email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
df_cleaned = df_cleaned.withColumn(
    "email_valid",
    regexp_extract(col("email"), email_pattern, 0) != ""
)
# Mark invalid emails as null but keep the record
df_cleaned = df_cleaned.withColumn(
    "email",
    when(col("email_valid") == False, lit(None)).otherwise(col("email"))
).drop("email_valid")

# 5. Handle negative purchase amounts - set to 0 or null
print("Fixing negative purchase amounts...")
df_cleaned = df_cleaned.withColumn(
    "purchase_amount",
    when(col("purchase_amount") < 0, lit(None)).otherwise(col("purchase_amount"))
)

# 6. Remove records with missing critical fields (customer_id)
print("Removing records with missing customer_id...")
df_cleaned = df_cleaned.filter(col("customer_id").isNotNull())

# 7. Trim whitespace from string columns only
print("Trimming whitespace...")
string_columns = ["first_name", "last_name", "email", "phone", "country"]
for col_name in string_columns:
    if col_name in df_cleaned.columns:
        df_cleaned = df_cleaned.withColumn(col_name, trim(col(col_name)))

print(f"Final cleaned row count: {df_cleaned.count()}")

# Show sample of cleaned data
print("Sample of cleaned data:")
df_cleaned.show(5, truncate=False)

# === WRITE OUTPUT ===
print(f"Writing cleansed data to: {OUTPUT_PATH}")

# Write as CSV for easy readability
df_cleaned.coalesce(1).write \
    .mode("overwrite") \
    .option("header", "true") \
    .csv(OUTPUT_PATH)

print("=== Data Cleansing Job Completed Successfully ===")

job.commit()
