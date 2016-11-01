data "aws_caller_identity" "current" { }

variable "schedule_min" {
    default = "30"
}

variable "schedule_hour" {
    default = "1" 
}

variable "region" {
  default = "eu-west-1"
}

provider "aws" {
    region = "${var.region}"
}

resource "aws_iam_role" "lambda_backup_role" {
    name = "lambda_backup_role"
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

resource "aws_iam_role_policy" "lambda_backup_policy" {
    name = "lambda_backup_policy"
    role = "${aws_iam_role.lambda_backup_role.id}"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "logs:*",
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:Describe*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateSnapshot",
        "ec2:DeleteSnapshot",
        "ec2:ModifySnapshotAttribute",
        "ec2:ResetSnapshotAttribute",
        "ec2:CreateTags",
        "ec2:DeleteTags"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_lambda_function" "lambda_backup_function" {
    filename = "lib/aws/dist/lambda-backup.zip"
    function_name = "lambda-backup"
    role = "${aws_iam_role.lambda_backup_role.arn}"
    handler = "lambda_backup.run_backup"
    runtime = "python2.7"
    timeout = "30"
    source_code_hash = "${base64sha256(file("lib/aws/dist/lambda-backup.zip"))}"
}

resource "aws_cloudwatch_event_rule" "lambda_backup_rule" {
  name = "LambdaBackup"
  description = "Trigger Lambda Backup"
  schedule_expression = "cron(${var.schedule_min} ${var.schedule_hour} * * ? *)"
}

resource "aws_cloudwatch_event_target" "lambda_backup_target" {
  target_id = "LambdaBackup"
  rule = "${aws_cloudwatch_event_rule.lambda_backup_rule.name}"
  arn = "${aws_lambda_function.lambda_backup_function.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch" {
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.lambda_backup_function.arn}"
    principal = "events.amazonaws.com"
    source_account = "${data.aws_caller_identity.current.account_id}"
    source_arn = "arn:aws:events:eu-west-1:${data.aws_caller_identity.current.account_id}:rule/LambdaBackup"
}