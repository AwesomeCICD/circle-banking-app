# Separate state file from the main circle-banking-app infrastructure.
# Same bucket, different key — keeps DNS concerns isolated so DNS
# changes can be reviewed/rolled back independently of app infra.
#
# Init:
#   terraform init \
#     -backend-config="bucket=fieldeng-cera-bucket-992382483259-us-east-1-an" \
#     -backend-config="region=us-east-1"

terraform {
  backend "s3" {
    key            = "circle-banking-app/dns.tfstate"
    encrypt        = true
    dynamodb_table = ""
  }
}
