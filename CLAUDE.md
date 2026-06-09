# CLAUDE.md -- Implementation Guide

This file is the primary reference for AI agents implementing the CERA-to-AWS migration for this repository. Read `docs/proposed-architecture.md` for full diagrams and rationale.

## Project Overview

**CCI Bank Corp** is a polyglot microservices banking application. It currently deploys to a CERA Kubernetes cluster that is being decommissioned. The goal is to migrate to a fully AWS-native architecture using EKS, DynamoDB, and modern tooling while showcasing a functional monorepo with CI/CD via CircleCI.

### Current Stack (being replaced)

- 3 Java 17 / Spring Boot services (balancereader, ledgerwriter, transactionhistory)
- 3 Python 3.10 / Flask services (frontend, userservice, contacts)
- 1 Python / Locust load generator
- 2 PostgreSQL 14 StatefulSets with emptyDir (ephemeral data)
- Istio for ingress, Argo Rollouts for canary, Vault for secrets, Jaeger for tracing
- Nexus container registry, Maven/Jib builds for Java

### Target Stack

- 3 Go services replacing Java (balancereader, ledgerwriter, transactionhistory)
- 3 Python services unchanged (frontend, userservice, contacts) with DynamoDB via boto3
- 1 Python load generator unchanged
- Amazon DynamoDB replacing PostgreSQL (4 tables, pay-per-request, serverless)
- AWS ALB for ingress, standard Deployments, Secrets Manager, Grafana+Tempo for tracing
- Amazon ECR, multi-stage Dockerfiles for Go, Cilium CNI with Hubble

## Target Architecture

See `docs/proposed-architecture.md` for full mermaid diagrams, comparison tables, and cost analysis.

Key points:
- **Single ALB** with host-based routing to 3 endpoints: `app.*`, `grafana.*`, `hubble.*`
- **Wildcard ACM cert** (`*.bankapp.example.com`) shared across all endpoints
- **DynamoDB** tables: Users, Contacts, Transactions, Balances (all pay-per-request)
- **No database containers** in the cluster -- all data in DynamoDB with IAM auth
- **Observability**: Grafana + Tempo (S3-backed) + Prometheus + OTEL Collector + Cilium Hubble
- **CircleCI + Docker + Kustomize** for CI/CD (Skaffold removed for demo simplicity)

## Implementation Order

Execute phases in order. Each phase should be a separate commit or PR.

### Phase 1: Terraform Infrastructure

Create `terraform/` directory with all `.tf` files.

| File | Creates |
|------|---------|
| `main.tf` | AWS provider (configurable region), Helm provider, Kubernetes provider, locals |
| `variables.tf` | `cluster_name`, `aws_region`, `domain_name`, `environment`, `circleci_org_id` |
| `outputs.tf` | EKS endpoint, ECR repo URIs, ALB DNS, DynamoDB table names, IAM role ARNs |
| `backend.tf` | S3 backend with DynamoDB locking (bucket/table names as variables) |
| `eks.tf` | EKS cluster (v1.29+), managed node group (t3.medium, 2-4 nodes), OIDC provider |
| `ecr.tf` | 7 ECR repos: `frontend`, `userservice`, `contacts`, `balancereader`, `ledgerwriter`, `transactionhistory`, `loadgenerator` |
| `dynamodb.tf` | 4 tables with schema below |
| `iam.tf` | IRSA roles for pods (DynamoDB + S3 access), CircleCI OIDC provider + role (ECR push, EKS deploy) |
| `route53.tf` | Hosted zone for `bankapp.example.com`, 3 alias records -> ALB |
| `acm.tf` | Wildcard cert `*.bankapp.example.com` with Route 53 DNS validation |
| `s3.tf` | `tempo-traces-{env}` bucket (lifecycle: 30-day retention), `frontend-assets-{env}` bucket |
| `secrets-manager.tf` | `circle-banking-app/jwt-private-key`, `circle-banking-app/jwt-public-key` |
| `cilium.tf` | Helm release for Cilium with Hubble enabled (`hubble.relay.enabled=true`, `hubble.ui.enabled=true`) |
| `alb-controller.tf` | Helm release for AWS LB Controller with IRSA service account |
| `cloudwatch.tf` | EKS addon `amazon-cloudwatch-observability` |
| `terraform.tfvars.example` | Example values for all variables |

**DynamoDB table schema:**

```hcl
# Users table
resource "aws_dynamodb_table" "users" {
  name         = "circle-banking-app-users-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"

  attribute {
    name = "userId"
    type = "S"
  }
}

# Contacts table
resource "aws_dynamodb_table" "contacts" {
  name         = "circle-banking-app-contacts-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"
  range_key    = "contactId"

  attribute {
    name = "userId"
    type = "S"
  }
  attribute {
    name = "contactId"
    type = "S"
  }
}

# Transactions table
resource "aws_dynamodb_table" "transactions" {
  name         = "circle-banking-app-transactions-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "accountId"
  range_key    = "timestampTxnId"

  attribute {
    name = "accountId"
    type = "S"
  }
  attribute {
    name = "timestampTxnId"
    type = "S"
  }
}

# Balances table
resource "aws_dynamodb_table" "balances" {
  name         = "circle-banking-app-balances-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "accountId"

  attribute {
    name = "accountId"
    type = "S"
  }
}
```

### Phase 2: Kubernetes Manifests

Create `kubernetes-manifests/` directory structure.

**`kubernetes-manifests/app/ingress.yaml`** -- single Ingress with 3 host rules:
- `app.{domain}` -> frontend:80
- `grafana.{domain}` -> grafana:3000
- `hubble.{domain}` -> hubble-ui:80

**`kubernetes-manifests/app/{service}/deployment.yaml`** for each of 7 services:
- Set `image:` to ECR URI placeholder (Skaffold will replace)
- Use `serviceAccountName` with IRSA-annotated service account for DynamoDB access
- Environment variables via ConfigMap: `DYNAMODB_USERS_TABLE`, `DYNAMODB_CONTACTS_TABLE`, `DYNAMODB_TRANSACTIONS_TABLE`, `DYNAMODB_BALANCES_TABLE`, `AWS_REGION`
- Resource requests/limits: Go services (cpu: 50m/200m, memory: 64Mi/128Mi), Python services (cpu: 100m/250m, memory: 128Mi/384Mi)

**`kubernetes-manifests/app/{service}/service.yaml`** for each service:
- ClusterIP services, port 8080 for Go services, port 8080 for Python services, port 80 for frontend

**`kubernetes-manifests/app/config.yaml`**:
- ConfigMap `environment-config` with `AWS_REGION`, DynamoDB table names
- ExternalSecret CRs for JWT keys from Secrets Manager

**`kubernetes-manifests/observability/`**:
- `grafana-values.yaml` -- Grafana Helm values with Tempo + Prometheus datasources preconfigured, service type ClusterIP
- `tempo-values.yaml` -- Tempo Helm values with S3 backend (`s3://tempo-traces-{env}/`), IRSA service account
- `prometheus-values.yaml` -- Prometheus Helm values with service discovery, retention 7d
- `otel-collector.yaml` -- OTEL Collector DaemonSet receiving OTLP on port 4317, exporting to Tempo (traces) and Prometheus remote-write (metrics)

**`kubernetes-manifests/overlays/dev/kustomization.yaml`** and `prod/`:
- Override replica counts, resource limits, image tags per environment

### Phase 3: Go Service Rewrites

Rewrite `src/balancereader/`, `src/ledgerwriter/`, `src/transactionhistory/` in Go.

**Each Go service needs:**
- `main.go` -- HTTP server (net/http or chi router), health endpoints (`/ready`, `/healthy`), OTEL instrumentation
- `go.mod` -- module path `github.com/circleci/circle-banking-app/{service}`
- `Dockerfile` -- multi-stage: `golang:1.22-alpine` build -> `gcr.io/distroless/static-debian12` runtime
- Unit tests in `*_test.go` files

**balancereader** (port 8080):
- `GET /balances/{accountId}` -- read from DynamoDB Balances table
- Uses `aws-sdk-go-v2` with DynamoDB client
- JWT token validation middleware (RS256, public key from mounted secret)

**ledgerwriter** (port 8080):
- `POST /transactions` -- write transaction + update balance atomically using DynamoDB TransactWriteItems
- JWT validation middleware
- Request validation (amount > 0, sender != receiver, sufficient balance)

**transactionhistory** (port 8080):
- `GET /transactions/{accountId}` -- query DynamoDB Transactions table by accountId, sorted by timestamp descending
- JWT validation middleware
- Pagination support via `lastEvaluatedKey`

**Go Dockerfile pattern:**

```dockerfile
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /server .

FROM gcr.io/distroless/static-debian12
COPY --from=builder /server /server
EXPOSE 8080
ENTRYPOINT ["/server"]
```

### Phase 4: Python Service DynamoDB Migration

Update `src/userservice/` and `src/contacts/` to use DynamoDB instead of PostgreSQL.

**`src/userservice/db.py`:**
- Replace `psycopg2` / SQLAlchemy with `boto3` DynamoDB resource
- `get_user(user_id)` -> `table.get_item(Key={"userId": user_id})`
- `create_user(user)` -> `table.put_item(Item=user)`
- `authenticate(username, password)` -> query by username (GSI or scan for demo)
- Read table name from `DYNAMODB_USERS_TABLE` env var

**`src/contacts/db.py`:**
- Replace `psycopg2` with `boto3`
- `get_contacts(user_id)` -> `table.query(KeyConditionExpression=Key("userId").eq(user_id))`
- `add_contact(user_id, contact)` -> `table.put_item(Item={"userId": user_id, "contactId": contact_id, ...})`
- `delete_contact(user_id, contact_id)` -> `table.delete_item(Key={"userId": user_id, "contactId": contact_id})`
- Read table name from `DYNAMODB_CONTACTS_TABLE` env var

**`src/userservice/requirements.txt`** and **`src/contacts/requirements.txt`:**
- Remove `psycopg2-binary`
- Add `boto3`

**`src/frontend/frontend.py`:**
- Remove any database connection string references
- Backend service URLs remain the same (ClusterIP service names)

### Phase 5: CircleCI Pipeline

Rewrite `.circleci/config.yml`. **No Skaffold** — use `docker build`/`docker push` and `kubectl apply` with Kustomize.

**Pipeline parameters:**
```yaml
parameters:
  ecr_registry:
    type: string
  eks_cluster_name:
    type: string
    default: "fe-runner-cluster"
  aws_region:
    type: string
    default: "us-east-1"
  k8s_namespace:
    type: string
    default: "circle-banking-app"
  domain:
    type: string
    default: "bankapp.example.com"
```

**Jobs:** `go-checkstyle`, `go-test`, `python-checkstyle`, `python-test`, `build-and-push`, `terraform-plan`, `terraform-apply`, `deploy-app`, `deploy-observability`, `e2e-test`

**Deploy app steps:**
1. OIDC auth → ECR login
2. `docker build` each service under `src/{service}`
3. `kustomize edit set image` in overlay temp dir
4. `kubectl apply -f -` after substituting IAM role + ACM cert placeholders
5. `kubectl rollout status` for each Deployment

### Phase 6: Cleanup

Delete the following files and directories:

```
src/accounts-db/                         # PostgreSQL replaced by DynamoDB
src/ledger-db/                           # PostgreSQL replaced by DynamoDB
src/ledgermonolith/                      # Legacy, not deployed
dev-kubernetes-manifests/                # Replaced by kubernetes-manifests/
istio-manifests/                         # Istio removed
pom.xml                                 # No more Java/Maven
mvnw                                    # No more Java/Maven
mvnw.cmd                                # No more Java/Maven
.mvn/                                   # No more Java/Maven
.circleci/vault/                        # Vault removed
.circleci/release_tracking/virtual_service_dev.yaml
.circleci/release_tracking/virtual_service_prod.yaml
extras/jwt/                             # JWT keys move to Secrets Manager
```

Update:
- `README.md` — update for new architecture, setup instructions, terraform commands
- `.gitignore` — add `terraform/.terraform/`, `terraform/*.tfstate*`

## External Dependencies

These must exist before Terraform or CircleCI can run:

1. **AWS account** with appropriate permissions
2. **Domain name** registered and delegated to Route 53 (or NS records pointing to Route 53 hosted zone)
3. **CircleCI OIDC** -- CircleCI org ID for the OIDC trust relationship in IAM
4. **S3 bucket + DynamoDB table** for Terraform state (bootstrap manually or use a separate bootstrap TF)
5. **CircleCI contexts** -- create contexts with `AWS_ROLE_ARN` for OIDC assume-role

## Key Technical Decisions

- **DynamoDB over RDS**: Pay-per-request mode scales to zero cost. IAM auth eliminates credential management. See `docs/proposed-architecture.md` for cost comparison.
- **Go over Java**: 10-20x smaller images, 100x faster startup. Multi-stage Dockerfiles replace Jib. See `docs/proposed-architecture.md` for full comparison.
- **Cilium over default CNI**: Enables Hubble network observability without sidecars. eBPF-based, zero per-pod overhead.
- **Grafana+Tempo over X-Ray**: Self-hosted, open-source, no per-trace charges. Tempo stores traces in S3. Grafana provides unified UI for traces + metrics + network flows.
- **Single ALB with host-based routing**: One ALB resource, one ACM wildcard cert, three Route 53 records. Cost-efficient, simple to manage.
- **Kustomize overlays**: `dev/` and `prod/` overrides for image tags, replica counts, resource limits without duplicating manifests.

## References

- [Current architecture](docs/architecture.md) -- existing CERA-based diagrams and pipeline
- [Proposed architecture](docs/proposed-architecture.md) -- full AWS-native diagrams, comparison tables, effort tiers
- [Agent guardrails](.cursor/rules/agent-guardrails.mdc) -- always confirm before pushing commits or creating PRs
