# Remote state uses S3 + DynamoDB locking.
# Backend values cannot reference Terraform variables, so pass them at init time:
#
#   terraform init \
#     -backend-config="bucket=<your-state-bucket>" \
#     -backend-config="dynamodb_table=<your-lock-table>" \
#     -backend-config="region=us-east-1"
#
# Or create a backend.hcl file (do not commit it) and run:
#   terraform init -backend-config=backend.hcl

terraform {
  backend "s3" {
    key     = "bankcorp/terraform.tfstate"
    encrypt = true
  }
}
