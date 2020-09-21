Lambda functions using boto3 to start or stop tagged EC2 instances every minute.  Example of using boto3 to manage AWS resources.

## Usage
1. Configure AWS credentials: ```aws configure```
2. Apply TF configuration: ```terraform apply```

## TODO:
1. Add test cases for tagged vs. untagged instances.
2. Refactor into module to improve DRY.
3. Refactor script into toggle OR use environment variables to toggle start/stop.
