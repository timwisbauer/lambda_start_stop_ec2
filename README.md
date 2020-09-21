Examples of Lambda functions leveraging boto3 to manage AWS resources.

* Examples
1. Start or stop tagged EC2 instances every minute.

* Usage
1. Configure AWS credentials: ```aws configure```
2. Apply TF configuration: ```terraform apply```

TODO:
1. Add test cases for tagged vs. untagged instances.
2. Refactor into module to improve DRY.
3. Refactor script into toggle OR use environment variables to toggle start/stop.
