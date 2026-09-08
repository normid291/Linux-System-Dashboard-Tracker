#1/bin/bash

##################################
#Author: Faiz-Ahmad
#Date Of Creation: 08/09/2026
#
#Version: V1
#
#Description: This script will report the resource usage on AWS(Amazon Web Service)
#
#The AWS Resources monitored:
#AWS EC2
#AWS S3
#AWS Lambda
#AWS IAM Users


# List s3 buckets
echo "List Of S3 Buckets"
aws s3 ls

# List AWS EC2 Instances ID
echo "List Of AWS EC2 Instances ID, Name, Running State"
aws ec2 describe-instances | jq -r '.Reservations[].Instances[] | {InstanceId, Name: (.Tags[]? | select(.Key=="Name") | .Value), State: .State.Name}'

# List AWS Lambda Function
echo "List Of AWS Lambda Functions"
aws lambda list-functions

# List IAM Users
echo "List Of IAM Users"
aws iam list-users
