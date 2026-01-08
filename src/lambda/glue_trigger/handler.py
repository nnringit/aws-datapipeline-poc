"""
Lambda function to trigger AWS Glue job when new files arrive in S3.

This function:
1. Receives S3 event notifications
2. Validates the file (optional custom logic)
3. Triggers the Glue ETL job
4. Logs execution details

Environment Variables:
    GLUE_JOB_NAME: Name of the Glue job to trigger (default: customer-data-cleansing-job)
    ALLOWED_EXTENSIONS: Comma-separated list of allowed file extensions (default: .csv)
    ALLOWED_PREFIXES: Comma-separated list of S3 prefixes to process (default: customers/)
"""

import json
import boto3
import os
import logging
from urllib.parse import unquote_plus

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize Glue client
glue_client = boto3.client('glue', region_name='eu-west-2')

# Configuration from environment variables
GLUE_JOB_NAME = os.environ.get('GLUE_JOB_NAME', 'customer-data-cleansing-job')
ALLOWED_EXTENSIONS = os.environ.get('ALLOWED_EXTENSIONS', '.csv').split(',')
ALLOWED_PREFIXES = os.environ.get('ALLOWED_PREFIXES', 'customers/').split(',')


def validate_file(bucket: str, key: str) -> tuple[bool, str]:
    """
    Validate if the file should trigger the Glue job.
    
    Add your custom validation logic here:
    - File extension checks
    - File size validation
    - Prefix/folder validation
    - Content type validation
    
    Returns:
        tuple: (is_valid, reason)
    """
    # Check file extension
    file_extension = os.path.splitext(key)[1].lower()
    if file_extension not in ALLOWED_EXTENSIONS:
        return False, f"File extension '{file_extension}' not in allowed list: {ALLOWED_EXTENSIONS}"
    
    # Check prefix/folder
    prefix_match = any(key.startswith(prefix) for prefix in ALLOWED_PREFIXES)
    if not prefix_match:
        return False, f"File prefix not in allowed list: {ALLOWED_PREFIXES}"
    
    # Skip _SUCCESS files and hidden files
    filename = os.path.basename(key)
    if filename.startswith('_') or filename.startswith('.'):
        return False, f"Skipping system/hidden file: {filename}"
    
    return True, "File validation passed"


def trigger_glue_job(bucket: str, key: str) -> dict:
    """
    Trigger the Glue ETL job with optional arguments.
    
    Args:
        bucket: S3 bucket name
        key: S3 object key
        
    Returns:
        dict: Glue job run response
    """
    # You can pass custom arguments to the Glue job
    job_arguments = {
        '--source_bucket': bucket,
        '--source_key': key,
        '--triggered_by': 'lambda-s3-event'
    }
    
    response = glue_client.start_job_run(
        JobName=GLUE_JOB_NAME,
        Arguments=job_arguments
    )
    
    return response


def lambda_handler(event, context):
    """
    Main Lambda handler for S3 event notifications.
    
    Args:
        event: S3 event notification
        context: Lambda context
        
    Returns:
        dict: Response with status and details
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    results = []
    
    for record in event.get('Records', []):
        try:
            # Extract S3 details
            bucket = record['s3']['bucket']['name']
            key = unquote_plus(record['s3']['object']['key'])
            size = record['s3']['object'].get('size', 0)
            event_name = record['eventName']
            
            logger.info(f"Processing: s3://{bucket}/{key} (size: {size}, event: {event_name})")
            
            # Validate file
            is_valid, reason = validate_file(bucket, key)
            
            if not is_valid:
                logger.info(f"Skipping file: {reason}")
                results.append({
                    'bucket': bucket,
                    'key': key,
                    'status': 'skipped',
                    'reason': reason
                })
                continue
            
            # Trigger Glue job
            response = trigger_glue_job(bucket, key)
            job_run_id = response['JobRunId']
            
            logger.info(f"Started Glue job run: {job_run_id}")
            
            results.append({
                'bucket': bucket,
                'key': key,
                'status': 'triggered',
                'job_run_id': job_run_id
            })
            
        except Exception as e:
            logger.error(f"Error processing record: {str(e)}")
            results.append({
                'bucket': record.get('s3', {}).get('bucket', {}).get('name', 'unknown'),
                'key': record.get('s3', {}).get('object', {}).get('key', 'unknown'),
                'status': 'error',
                'error': str(e)
            })
    
    response = {
        'statusCode': 200,
        'body': {
            'message': f'Processed {len(results)} file(s)',
            'results': results
        }
    }
    
    logger.info(f"Response: {json.dumps(response)}")
    return response
