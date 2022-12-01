pid_file = "./pidfile"
exit_after_auth = true

auto_auth {
  method "approle" {
    config = {
      role_id_file_path = "vault/role-id"
      secret_id_file_path = "vault/secret-id"
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
    {{ with secret "secret/boa/deployer" }}
    export K8S_TOKEN={{ .Data.token }}
    export K8S_CERT={{ .Data.cert }}
    export K8S_USER={{ .Data.user }}
    export K8S_URL={{ .Data.url }}
    {{ end }}
  EOF
  destination = ".circleci/vault/cluster"
}
