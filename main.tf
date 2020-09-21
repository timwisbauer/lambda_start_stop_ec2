provider "aws" {
  region = "us-east-1"
}

data "aws_iam_policy_document" "start_stop_ec2_policydoc" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }

  statement {
    actions = ["ec2:DescribeInstances",
      "ec2:DescribeRegions",
      "ec2:StartInstances",
    "ec2:StopInstances"]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_role" "start_stop_ec2_role" {
  name = "start_stop_ec2_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "start_stop_ec2_policy" {
  name = "start_stop_ec2_policy"
  policy = data.aws_iam_policy_document.start_stop_ec2_policydoc.json
}

resource "aws_iam_role_policy_attachment" "start_stop_ec2_attachment" {
  role       = aws_iam_role.start_stop_ec2_role.name
  policy_arn = aws_iam_policy.start_stop_ec2_policy.arn
}

data "archive_file" "stop_ec2" {
  type        = "zip"
  source_file = "stop_ec2.py"
  output_path = "stop_ec2.zip"
}

resource "aws_lambda_function" "stop_ec2" {
  filename      = "stop_ec2.zip"
  function_name = "stop_ec2"
  role          = aws_iam_role.start_stop_ec2_role.arn
  handler       = "stop_ec2.lambda_handler"
  description   = "Stops EC2 instances based on tag."
  timeout       = 60

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = data.archive_file.stop_ec2.output_base64sha256

  runtime = "python3.8"

}

data "archive_file" "start_ec2" {
  type        = "zip"
  source_file = "start_ec2.py"
  output_path = "start_ec2.zip"
}

resource "aws_lambda_function" "start_ec2" {
  filename      = "start_ec2.zip"
  function_name = "start_ec2"
  role          = aws_iam_role.start_stop_ec2_role.arn
  handler       = "start_ec2.lambda_handler"
  description   = "Starts EC2 instances based on tag."
  timeout       = 60

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = data.archive_file.start_ec2.output_base64sha256

  runtime = "python3.8"

}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "lambda_scheduled_instances" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.nano"

  tags = {
    lambda_scheduled = "true"
  }
}

resource "aws_cloudwatch_event_rule" "stop_even_minutes" {
  name                = "stop-even-minutes"
  description         = "Fires on even minutes"
  schedule_expression = "cron(0/2 * ? * * *)"
}

resource "aws_cloudwatch_event_target" "stop-instances-even-minutes" {
  rule      = aws_cloudwatch_event_rule.stop_even_minutes.name
  target_id = "lambda"
  arn       = aws_lambda_function.stop_ec2.arn
}

resource "aws_cloudwatch_event_rule" "start_odd_minutes" {
  name                = "start-odd-minutes"
  description         = "Fires on odd minutes"
  schedule_expression = "cron(1/2 * ? * * *)"
}

resource "aws_cloudwatch_event_target" "start-instances-odd-minutes" {
  rule      = aws_cloudwatch_event_rule.start_odd_minutes.name
  target_id = "lambda"
  arn       = aws_lambda_function.start_ec2.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_stop_ec2" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop_ec2.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_even_minutes.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_start_ec2" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_ec2.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start_odd_minutes.arn
}