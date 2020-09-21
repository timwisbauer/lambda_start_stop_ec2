import botocore
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):

    ec2_client = boto3.client('ec2')

    # Iterate over all regions.
    for region in ec2_client.describe_regions()['Regions']:
        logger.info(f"Region: {region}")
        try: 
            ec2_resource = boto3.resource('ec2', region_name = region['RegionName'])

            # Get stopped and tagged instances.
            instances = ec2_resource.instances.filter(
                Filters=[{'Name': 'instance-state-name',
                        'Values': ['running']}, 
                        {'Name':'tag:lambda_scheduled', 'Values': ['true']}]
            )
            logger.info(instances)
            for instance in instances:
                logger.info(f"Stopping instance: {instance.id}")
                instance.stop()
        except botocore.exceptions.ClientError as err:
            logger.error(f"Error with region {region['RegionName']}: {err}")
