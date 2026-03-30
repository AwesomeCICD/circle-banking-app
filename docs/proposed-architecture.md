# CCI Bank Corp -- Proposed AWS-Native Architecture

## Architecture Overview

![Proposed AWS Architecture](proposed-architecture.png)

## Proposed Architecture Diagram (Mermaid)

```mermaid
flowchart TB
    subgraph external [External Traffic]
        User["User / Browser"]
        LoadGen["loadgenerator\n(Python / Locust)\nruns in EKS"]
    end

    subgraph dns_tls [DNS and TLS]
        R53["Amazon Route 53"]
        ACM["AWS Certificate Manager\n(TLS termination)"]
    end

    subgraph cdn [Static Assets]
        CF["Amazon CloudFront"]
        S3Static["S3 Bucket\n(frontend static assets)"]
    end

    subgraph eks [Amazon EKS Cluster]
        ALB["AWS ALB\n(via Load Balancer Controller)"]

        subgraph fe_tier [Frontend Tier]
            Frontend["frontend\n(Python / Flask)\nstandard Deployment"]
        end

        subgraph backend_tier [Backend Services]
            UserSvc["userservice\n(Python / Flask)"]
            Contacts["contacts\n(Python / Flask)"]
            BalReader["balancereader\n(Java 17 / Spring Boot)"]
            LedWriter["ledgerwriter\n(Java 17 / Spring Boot)"]
            TxHistory["transactionhistory\n(Java 17 / Spring Boot)"]
        end

        ADOT["ADOT Collector\n(DaemonSet)"]
        ESO["External Secrets\nOperator"]
    end

    subgraph aws_data [AWS Managed Data]
        RDS_Accounts["Amazon RDS PostgreSQL\n(accounts-db)"]
        RDS_Ledger["Amazon RDS PostgreSQL\n(ledger-db)"]
        Redis["Amazon ElastiCache\n(Redis - balance cache)"]
        DDB["Amazon DynamoDB\n(sessions / feature flags)\n-- optional --"]
    end

    subgraph aws_infra [AWS Infrastructure Services]
        ECR["Amazon ECR\n(9 container images)"]
        SM["AWS Secrets Manager\n(DB creds, JWT keys)"]
        XRay["AWS X-Ray\n(distributed tracing)"]
        CW["Amazon CloudWatch\n(logs, metrics, insights)"]
        S3State["S3 + DynamoDB\n(Terraform state)"]
    end

    subgraph cicd [CircleCI]
        Pipeline["CircleCI Pipeline\n(OIDC -> AWS IAM)"]
    end

    User --> R53
    R53 --> ALB
    ACM --> ALB
    User --> CF
    CF --> S3Static

    ALB --> Frontend
    LoadGen --> Frontend

    Frontend --> UserSvc
    Frontend --> Contacts
    Frontend --> BalReader
    Frontend --> LedWriter
    Frontend --> TxHistory

    UserSvc --> RDS_Accounts
    Contacts --> RDS_Accounts
    BalReader --> RDS_Ledger
    LedWriter --> RDS_Ledger
    TxHistory --> RDS_Ledger

    BalReader --> Redis

    Frontend -.-> DDB

    ESO --> SM
    ADOT --> XRay
    ADOT --> CW

    Pipeline --> ECR
    Pipeline --> eks
    Pipeline --> S3State
```

---

## Proposed CI/CD Pipeline

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

    subgraph build [Build]
        BuildPush["Skaffold build + push\n(CircleCI OIDC -> ECR)"]
    end

    subgraph deployDev [Deploy Dev]
        DeployDev["Deploy Dev\n(OIDC -> IAM -> eks update-kubeconfig)\nSkaffold deploy + kubectl rollout status"]
    end

    subgraph e2e [E2E Tests]
        E2E["Cypress on Firefox\n(ALB endpoint)"]
    end

    subgraph deployProd [Deploy Production - main branch only]
        DeployProd["Deploy Production\n(OIDC -> IAM -> EKS)"]
    end

    BuildPush --> DeployDev
    JavaTest --> DeployDev
    PyTest --> DeployDev

    DeployDev --> E2E
    E2E --> DeployProd
```

### Infrastructure Dependencies Per Stage

- **Build** -- CircleCI OIDC assumes an IAM role with ECR push permissions; Skaffold builds all 9 images and pushes to ECR with git SHA tags
- **Deploy Dev** -- CircleCI OIDC assumes an IAM role with EKS access; `aws eks update-kubeconfig` configures kubectl; Skaffold deploy applies manifests; `kubectl rollout status` confirms health
- **E2E** -- Cypress runs against the ALB endpoint (Route 53 DNS name)
- **Deploy Prod** -- Same as Dev but uses a separate IAM role / context and only runs on `main` branch

---

## Current vs. Proposed Comparison

| Concern | Current (CERA) | Proposed (AWS) |
|---------|---------------|----------------|
| **Container registry** | Nexus on CERA | Amazon ECR |
| **Cluster** | CERA k8s | Amazon EKS |
| **Ingress** | Istio Gateway + VirtualService | AWS ALB (Load Balancer Controller) |
| **TLS** | Manual / Istio | AWS Certificate Manager (free, auto-renewing) |
| **DNS** | `*.circleci-fieldeng.com` | Amazon Route 53 |
| **Frontend deploy strategy** | Argo Rollout (canary) | Standard Deployment (rolling update) |
| **accounts-db** | PostgreSQL StatefulSet (emptyDir -- ephemeral!) | Amazon RDS PostgreSQL (persistent, managed) |
| **ledger-db** | PostgreSQL StatefulSet (emptyDir -- ephemeral!) | Amazon RDS PostgreSQL (persistent, managed) |
| **Balance cache** | In-memory (lost on restart) | Amazon ElastiCache Redis (shared, persistent) |
| **Sessions / config** | None | Amazon DynamoDB (optional) |
| **Static assets** | Served by frontend pod | S3 + CloudFront |
| **Secrets** | Vault on CERA + plaintext ConfigMaps | AWS Secrets Manager + External Secrets Operator |
| **Tracing** | Jaeger on CERA | AWS X-Ray via ADOT Collector |
| **Monitoring** | None explicit | CloudWatch Container Insights |
| **CI/CD auth** | Vault OIDC | CircleCI OIDC -> AWS IAM |
| **IaC state** | None | S3 + DynamoDB (Terraform) |
| **Multi-region strategy** | Matrix per CERA region (emea, namer) | Single cluster (configurable via pipeline params) |

---

## Effort Tiers

### Infra-only (no app code changes)

- **EKS, ECR, ALB, ACM, Route 53** -- core platform, already planned
- **Amazon RDS PostgreSQL** -- replace in-cluster StatefulSets; only connection string env vars change
- **AWS Secrets Manager + External Secrets Operator** -- inject secrets into k8s, remove plaintext ConfigMaps
- **CloudWatch Container Insights** -- install EKS addon
- **S3 + DynamoDB for Terraform state** -- backend configuration

### Minor app code changes

- **Amazon ElastiCache Redis** -- update `balancereader` cache config to use Redis instead of in-memory (`CACHE_SIZE` env var)
- **AWS X-Ray via ADOT Collector** -- swap OTEL exporter endpoint from Jaeger to ADOT DaemonSet; add X-Ray propagator
- **CloudFront + S3 for static assets** -- extract CSS/JS/images from frontend container, serve from S3

### Optional / future (larger scope)

- **Amazon DynamoDB for sessions / feature flags** -- requires adding session middleware to the frontend Flask app
- **CloudFront + S3** -- can be deferred if frontend pod performance is acceptable

---

## AWS Services Summary

| AWS Service | Purpose | Required? |
|-------------|---------|-----------|
| Amazon EKS | Run microservices | Yes |
| Amazon ECR | Container image registry | Yes |
| AWS ALB + LB Controller | Ingress and traffic routing | Yes |
| Amazon RDS PostgreSQL | Managed databases (accounts-db, ledger-db) | Yes |
| AWS Secrets Manager | Store DB creds, JWT keys, API keys | Yes |
| External Secrets Operator | Sync Secrets Manager into k8s Secrets | Yes |
| AWS Certificate Manager | TLS certificates for ALB | Yes |
| Amazon Route 53 | DNS management | Yes |
| CircleCI OIDC + AWS IAM | CI/CD authentication | Yes |
| Amazon CloudWatch | Logs, metrics, container insights | Yes |
| S3 (Terraform state) | IaC state backend | Yes |
| AWS X-Ray + ADOT | Distributed tracing | Recommended |
| Amazon ElastiCache Redis | Shared balance cache | Recommended |
| Amazon CloudFront + S3 | Static asset CDN | Optional |
| Amazon DynamoDB | Sessions, feature flags | Optional |
