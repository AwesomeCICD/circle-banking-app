# Remote state in S3 (no DynamoDB lock table — serial-group in CircleCI
# prevents concurrent applies). Bucket and region passed at init time:
#
#   terraform init \
#     -backend-config="bucket=fieldeng-cera-bucket-..." \
#     -backend-config="region=us-east-1"

terraform {
  backend "s3" {
    key            = "bankcorp/terraform.tfstate"
    encrypt        = true
    use_lockfile   = false
  }
}
