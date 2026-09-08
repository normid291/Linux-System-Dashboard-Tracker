# AWS Resource Tracker

A simple Bash script to report on active AWS resource usage across your account — built as a quick way to audit what's running without digging through the AWS Console.

**Author:** Faiz-Ahmad
**Version:** v1

## Resources Monitored

- **EC2** — Instance ID, Name tag, and running state
- **S3** — List of all buckets
- **Lambda** — List of all functions
- **IAM** — List of all users

## Prerequisites

Before running this script, make sure you have:

1. **AWS CLI** installed and configured with valid credentials
   ```bash
   aws configure
   ```
   This requires an AWS Access Key ID, Secret Access Key, and default region.

2. **jq** installed (used to parse and format the EC2 JSON output)
   ```bash
   # Ubuntu/Debian/WSL
   sudo apt update && sudo apt install -y jq

   # Amazon Linux/RHEL/CentOS
   sudo yum install -y jq

   # macOS
   brew install jq
   ```

3. IAM permissions to run:
   - `ec2:DescribeInstances`
   - `s3:ListAllMyBuckets`
   - `lambda:ListFunctions`
   - `iam:ListUsers`

## Usage

Make the script executable, then run it:

```bash
chmod +x aws-resource-tracker.sh
./aws-resource-tracker.sh
```

### Example Output

```
List Of S3 Buckets
my-bucket-1
my-bucket-2

List Of AWS EC2 Instances ID, Name, Running State
{
  "InstanceId": "i-06df44069479016f9",
  "Name": "devops-learning",
  "State": "running"
}

List Of AWS Lambda Functions
...

List Of IAM Users
...
```

## Customizing the EC2 Output

By default, the EC2 section only shows **Instance ID, Name, and State** for a quick overview. If you want the **full instance details** instead (all fields returned by AWS — networking, security groups, block devices, tags, etc.), edit this line in `aws-resource-tracker.sh`:

**Default (summary view):**
```bash
aws ec2 describe-instances | jq -r '.Reservations[].Instances[] | {InstanceId, Name: (.Tags[]? | select(.Key=="Name") | .Value), State: .State.Name}'
```

**Full details (raw output, no filtering):**
```bash
aws ec2 describe-instances
```

**Full details, pretty-printed with jq (still complete, just formatted):**
```bash
aws ec2 describe-instances | jq '.'
```

You can also customize which fields show up in the summary view by editing the `jq` filter. For example, to also include the instance type and public IP:

```bash
aws ec2 describe-instances | jq -r '.Reservations[].Instances[] | {InstanceId, Name: (.Tags[]? | select(.Key=="Name") | .Value), State: .State.Name, InstanceType, PublicIp: .PublicIpAddress}'
```

## Notes

- This script does **not** store or commit any AWS credentials — make sure your credentials stay in `~/.aws/credentials` and are never added to this repo.
- Output is printed directly to the terminal; redirect to a file if you want to save it:
  ```bash
  ./aws-resource-tracker.sh > report.txt
  ```

## License

Feel free to use and modify this script for your own AWS resource tracking needs.
