# Remote state in S3. Bucket and region are passed at init time:
#
#   terraform init \
#     -backend-config="bucket=fieldeng-cera-bucket-..." \
#     -backend-config="region=us-east-1"
#
# Locking is handled by CircleCI serial-group, not DynamoDB.

terraform {
  backend "s3" {
    key            = "circle-banking-app/terraform.tfstate"
    encrypt        = true
    dynamodb_table = ""
  }
}
