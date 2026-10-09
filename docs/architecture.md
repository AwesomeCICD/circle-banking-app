# CCI Bank Corp -- Architecture & CI/CD Pipeline

## Application Architecture & Tech Stack

Shows every service, how they communicate, the databases, and the infrastructure components currently in use.

```mermaid
flowchart TB
    subgraph external [External Traffic]
        User["User / Browser"]
        LoadGen["loadgenerator\n(Python / Locust)"]
    end

    subgraph infra [CERA Infrastructure]
        Vault["HashiCorp Vault\n(OIDC auth, cluster creds)"]
        Nexus["Nexus Docker Registry\n(docker.nexus.region.circleci-fieldeng.com)"]
        Jaeger["Jaeger\n(Tracing via OTEL)"]
    end

    subgraph istio [Istio Ingress Layer]
        GW["Istio Gateway"]
        VS["VirtualService\n(canary weight routing)"]
    end

    subgraph k8s [CERA Kubernetes Cluster]
        subgraph fe [Frontend Tier]
            Frontend["frontend\n(Python / Flask / Gunicorn)\nArgo Rollout - canary"]
            FeSvc["frontend Service\n+ frontend-canary Service"]
        end

        subgraph backend_svc [Backend Services]
            UserSvc["userservice\n(Python / Flask)"]
            Contacts["contacts\n(Python / Flask)"]
            BalReader["balancereader\n(Java 17 / Spring Boot)"]
            LedWriter["ledgerwriter\n(Java 17 / Spring Boot)"]
            TxHistory["transactionhistory\n(Java 17 / Spring Boot)"]
        end

        subgraph db [Data Tier]
            AccountsDB["accounts-db\n(PostgreSQL 14)\nStatefulSet"]
            LedgerDB["ledger-db\n(PostgreSQL 14)\nStatefulSet"]
        end

        JWT["jwt-key Secret\n(RSA key pair)"]
    end

    User --> GW
    GW --> VS
    VS --> FeSvc
    FeSvc --> Frontend
    LoadGen --> Frontend

    Frontend --> UserSvc
    Frontend --> Contacts
    Frontend --> BalReader
    Frontend --> LedWriter
    Frontend --> TxHistory

    UserSvc --> AccountsDB
    Contacts --> AccountsDB
    BalReader --> LedgerDB
    LedWriter --> LedgerDB
    TxHistory --> LedgerDB

    UserSvc --> JWT
    Frontend --> JWT
    Contacts --> JWT
    BalReader --> JWT
    LedWriter --> JWT
    TxHistory --> JWT

    UserSvc -.-> Jaeger
    Contacts -.-> Jaeger
    Frontend -.-> Jaeger
```

### Build Methods

| Service | Language | Build Method | Base Image |
|---------|----------|-------------|------------|
| `balancereader` | Java 17 / Spring Boot | Jib (no Dockerfile) | -- |
| `ledgerwriter` | Java 17 / Spring Boot | Jib (no Dockerfile) | -- |
| `transactionhistory` | Java 17 / Spring Boot | Jib (no Dockerfile) | -- |
| `frontend` | Python 3.10 / Flask | Dockerfile | `python:3.10-slim` |
| `userservice` | Python 3.10 / Flask | Dockerfile | `python:3.10-slim` |
| `contacts` | Python 3.10 / Flask | Dockerfile | `python:3.10-slim` |
| `loadgenerator` | Python 3.10 / Locust | Dockerfile | `python:3.10-slim` |
| `accounts-db` | PostgreSQL 14 | Dockerfile | `postgres:14-alpine` |
| `ledger-db` | PostgreSQL 14 | Dockerfile | `postgres:14-alpine` |

All 9 images are pushed to Nexus via Skaffold with git SHA tags.

---

## CI/CD Pipeline (CircleCI Workflow)

Shows every job, its dependencies, and the per-region matrix strategy defined in `.circleci/config.yml`.

```mermaid
flowchart TD
    subgraph lint [Lint - parallel, no deps]
        JavaLint["java-checkstyle\n(JDK 17, Maven)"]
        PyLint["python-checkstyle\n(Python 3.8, pylint)"]
    end

    subgraph test [Test - parallel, no deps]
        JavaTest["java-test-and-code-cov\n(JDK 17, Maven + JUnit)"]
        PyTest["python-test\n(pytest, sequential)"]
        PyTestPar["python-test-parallel\n(pytest, parallelism: 2)"]
    end

    subgraph build [Build - per region matrix]
        BuildEMEA["Skaffold build and Push\n[emea]\n(Vault OIDC -> Nexus)"]
        BuildNAMER["Skaffold build and Push\n[namer]\n(Vault OIDC -> Nexus)"]
    end

    subgraph deployDev [Deploy Dev - per region]
        DeployDevEMEA["Deploy Dev [emea]\n(Vault -> kubectl -> Skaffold deploy)\n+ Compass notify"]
        DeployDevNAMER["Deploy Dev [namer]\n(Vault -> kubectl -> Skaffold deploy)\n+ Compass notify"]
    end

    subgraph e2eTests [E2E Tests - per region]
        E2EEMEA["e2e [emea]\n(Cypress on Firefox)\ndev.emea.circleci-fieldeng.com"]
        E2ENAMER["e2e [namer]\n(Cypress on Firefox)\ndev.namer.circleci-fieldeng.com"]
    end

    subgraph deployProd [Deploy Production - main branch only, per region]
        DeployProdEMEA["Deploy Production [emea]\n+ Compass notify"]
        DeployProdNAMER["Deploy Production [namer]\n+ Compass notify"]
    end

    BuildEMEA --> DeployDevEMEA
    BuildNAMER --> DeployDevNAMER
    JavaTest --> DeployDevEMEA
    JavaTest --> DeployDevNAMER
    PyTest --> DeployDevEMEA
    PyTest --> DeployDevNAMER

    DeployDevEMEA --> E2EEMEA
    DeployDevNAMER --> E2ENAMER

    E2EEMEA --> DeployProdEMEA
    E2ENAMER --> DeployProdNAMER
```

### Infrastructure Dependencies Per Stage

- **Build** -- Vault OIDC (`cera-vault-oidc` context) fetches Nexus Docker credentials, then Skaffold builds all 9 images and pushes to `docker.nexus.<region>.circleci-fieldeng.com`
- **Deploy Dev** -- Vault OIDC fetches k8s cluster credentials (`K8S_TOKEN`, `K8S_CERT`, `K8S_URL`, `K8S_NAMESPACE`), configures kubectl manually, runs Skaffold deploy, waits for Argo Rollout, notifies Compass
- **E2E** -- Cypress runs against `https://dev.<region>.circleci-fieldeng.com` (Istio-routed)
- **Deploy Prod** -- Same as Dev but uses `cera-vault-oidc-prod` context and only runs on `main` branch
