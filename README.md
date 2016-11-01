![Lambda Backup](https://lambdabackup.com/lambda-backup-logo.png)

# Lambda Backup
A drop-in solution to create Amazon Web Services EBS snapshots on a schedule. Enable daily backups of your AWS EC2 infrastructure in 10 seconds with zero configuration and no need for backup a server.

Lambda Backup will use your AWS credentials to install an AWS Lambda function that will traverse the list of your EC2 instances, and create snapshots of all attached volumes. It will then clean up any snapshots that are set to be deleted. Lambda Backup will schedule this function to run every night between 1 and 2 am. The exact time is randomized.

## Configuration
By default, Lambda Backup backs up all of your EC2 instances every night. It preserves three daily backups, four weekly backups (taken on Mondays) and twelve monthly backups (taken on the first day of each month).

Each EBS volume attached to your EC2 instances will be backed up separately. To disable backups for an instance, set a tag with the name ```LambdaBackupStrategy``` and the value ```Never```.

If you wish to change these default values, refer to ```lib/aws/src/lambda_backup.py```.

## Requirements
- AWS credentials that can create Lambda functions
- A recent version of OS X or Linux with Bash
- Terraform (if not installed, it will be downloaded)

## Quick Start
```
git clone git@github.com:andigital/lambda-backup.git
cd lambda-backup
AWS_DEFAULT_REGION=<aws-region-here> AWS_ACCESS_KEY_ID=<your-aws-access-key-here> AWS_SECRET_ACCESS_KEY=<your-aws-secret-key-here> ./setup.sh enable
```

## To disable backups and tear down the Lambda function
```
AWS_DEFAULT_REGION=<aws-region-here> AWS_ACCESS_KEY_ID=<your-aws-access-key-here> AWS_SECRET_ACCESS_KEY=<your-aws-secret-key-here> ./setup.sh disable
```

## Caveats
- Lambda Backup will only back up data that has been written on the EBS volumes. This may not always reflect the state your instance is in -- for example databases tend to utilise in-memory cache extensively. To work around this, you can create a dump of your database in a file separately.
- When you enable backups, the state of resources is written in the file terraform.tfstate. If you lose this file, you will not be able to disable the backups by using the script - you will instead need to remove the created resources manually.
