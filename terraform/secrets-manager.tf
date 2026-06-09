# JWT keys are stored in Secrets Manager and synced into Kubernetes Secret `jwt-keys`
# by the deploy-dev / Deploy Production CircleCI jobs at deploy time.
# Initial value is a placeholder string; deploy-dev auto-generates an RSA 2048 keypair
# on the first run when it sees the placeholder, then calls put-secret-value.

resource "aws_secretsmanager_secret" "jwt_private_key" {
  name                    = "circle-banking-app/jwt-private-key"
  description             = "RSA private key for signing JWT tokens (circle-banking-app userservice)"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "jwt_private_key" {
  secret_id     = aws_secretsmanager_secret.jwt_private_key.id
  secret_string = "PLACEHOLDER"

  # Real key material is written by the deploy-dev bootstrap step; Terraform
  # should not overwrite it on subsequent applies.
  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret" "demo_password" {
  name                    = "circle-banking-app/demo-password"
  description             = "Password for demo seed users"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "demo_password" {
  secret_id     = aws_secretsmanager_secret.demo_password.id
  secret_string = "PLACEHOLDER"

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret" "jwt_public_key" {
  name                    = "circle-banking-app/jwt-public-key"
  description             = "RSA public key for verifying JWT tokens (circle-banking-app services)"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "jwt_public_key" {
  secret_id     = aws_secretsmanager_secret.jwt_public_key.id
  secret_string = "PLACEHOLDER"

  lifecycle {
    ignore_changes = [secret_string]
  }
}
