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

# Consolidated app secrets as a single JSON key/value secret.
# Keys: demo_username, demo_password, grafana_admin_username, grafana_admin_password
# Set values via:
#   aws secretsmanager put-secret-value \
#     --secret-id AwesomeCICD/circle-banking-app/secrets \
#     --secret-string '{"demo_username":"...","demo_password":"...","grafana_admin_username":"admin","grafana_admin_password":"..."}'
resource "aws_secretsmanager_secret" "app_secrets" {
  name                    = "AwesomeCICD/circle-banking-app/secrets"
  description             = "Consolidated app secrets (JSON key/value pairs)"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    demo_username          = "PLACEHOLDER"
    demo_password          = "PLACEHOLDER"
    grafana_admin_username = "PLACEHOLDER"
    grafana_admin_password = "PLACEHOLDER"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
