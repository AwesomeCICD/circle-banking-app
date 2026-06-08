# JWT keys are stored in Secrets Manager and mounted into pods via External Secrets Operator.
# The secret resources are created here with placeholder values.
# Set the real key material after apply:
#   aws secretsmanager put-secret-value --secret-id bankcorp/jwt-private-key --secret-string "$(cat jwt.pem)"

resource "aws_secretsmanager_secret" "jwt_private_key" {
  name                    = "bankcorp/jwt-private-key"
  description             = "RSA private key for signing JWT tokens (bankcorp userservice)"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "jwt_private_key" {
  secret_id     = aws_secretsmanager_secret.jwt_private_key.id
  secret_string = "PLACEHOLDER — replace with actual RSA private key PEM"

  # Prevent Terraform from overwriting the real key once it has been set manually.
  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret" "jwt_public_key" {
  name                    = "bankcorp/jwt-public-key"
  description             = "RSA public key for verifying JWT tokens (bankcorp services)"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "jwt_public_key" {
  secret_id     = aws_secretsmanager_secret.jwt_public_key.id
  secret_string = "PLACEHOLDER — replace with actual RSA public key PEM"

  lifecycle {
    ignore_changes = [secret_string]
  }
}
