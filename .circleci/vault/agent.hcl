pid_file = "./pidfile"
exit_after_auth = true

vault {
  address = "https://vault.cera.circleci-labs.com"
  retry {
    num_retries = -1
  }
}


auto_auth {
  method "jwt" {
    config = {
      role = "boa-dev-deploy"
      path = ".circleci/vault/token.json"
      remove_jwt_after_reading = false
    }
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
  contents = <<EOF
    {{ with secret "secret/nexus/boa-deployer" }}
    export DOCKER_LOGIN="{{ .Data.data.username }}"
    export DOCKER_PWD="{{ .Data.data.password }}"
    {{ end }}
  EOF
  destination = ".circleci/vault/dockerhub"
}

template {
  source      = ".circleci/vault/template.ctmpl"
  destination = ".circleci/vault/cluster"
}