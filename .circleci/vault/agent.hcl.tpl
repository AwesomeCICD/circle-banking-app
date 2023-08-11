pid_file = "./pidfile"
exit_after_auth = true

vault {
  address = "${VAULT_ADDR}"
  retry {
    num_retries = 1
  }
}


auto_auth {
  method "jwt" {
    mount_path = "auth/jwt"
    config = {
      role = "${VAULT_ROLE}"
      path = ".circleci/vault/token.json"
      remove_jwt_after_reading = false
    }
    exit_on_err = true
  }

  sink "file" {
    config = {
      path = "/tmp/vault-token"
    }
  }
}

template_config {
  exit_on_retry_failure = true
}



template {
  source      = ".circleci/vault/cluster.ctmpl"
  destination = ".circleci/vault/setenv"
}
