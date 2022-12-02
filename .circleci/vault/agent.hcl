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
  contents = <<EOF
    {{ with secret "secret/cluster/boa-pipeline-dev" }}
    export K8S_TOKEN="{{ .Data.data.token }}"
    export K8S_CERT="{{ .Data.data.cert }}"
    export K8S_USER={{ .Data.data.user }}
    export K8S_NAMESPACE={{ .Data.data.namespace }}
    export K8S_URL="{{ .Data.data.url }}"
    {{ end }}
  EOF
  destination = ".circleci/vault/cluster"
}
template {
  contents = <<EOF
    {{ with secret "secret/cluster/boa-pipeline-dev" }}
    echo "export K8S_TOKEN=\"{{ .Data.data.token }}\"" >> $BASH_ENV
    echo "export K8S_CERT=\"{{ .Data.data.cert }}\"" >> $BASH_ENV
    echo "export K8S_USER={{ .Data.data.user }}" >> $BASH_ENV
    echo "export K8S_NAMESPACE={{ .Data.data.namespace }}" >> $BASH_ENV
    echo "export K8S_URL=\"{{ .Data.data.url }}\"" >> $BASH_ENV
    {{ end }}
  EOF
  destination = ".circleci/vault/cluster.export"
}
