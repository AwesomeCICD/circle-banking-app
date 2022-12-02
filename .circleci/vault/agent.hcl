pid_file = "./pidfile"
exit_after_auth = true

vault {
  address = "https://vault.cera.circleci-labs.com"

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

template {
  contents = <<EOF
    {{ with secret "secret/nexus/boa-deployer" }}
    export DOCKER_LOGIN={{ .Data.username }}
    export DOCKER_PWD={{ .Data.password }}
    {{ end }}
  EOF
  destination = ".circleci/vault/dockerhub"
}

template {
  contents = <<EOF
    {{ with secret "secret/cluster/boa-pipeline-dev" }}
    export K8S_TOKEN={{ .Data.token }}
    export K8S_CERT={{ .Data.cert }}
    export K8S_USER={{ .Data.user }}
    export K8S_URL={{ .Data.url }}
    {{ end }}
  EOF
  destination = ".circleci/vault/cluster"
}
