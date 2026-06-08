# Migration Phases — CERA to AWS

This document summarizes each phase of the CCI Bank Corp migration from CERA Kubernetes to AWS-native infrastructure. See [`proposed-architecture.md`](proposed-architecture.md) for full diagrams and rationale.

## Phase 1 — Terraform Infrastructure

Creates all AWS infrastructure via `terraform/`:

- EKS cluster (v1.29+, t3.medium managed node group)
- 7 ECR repositories (one per service image)
- 4 DynamoDB tables: Users, Contacts, Transactions, Balances (all pay-per-request)
- Single ALB with host-based routing to `app.*`, `grafana.*`, `hubble.*`
- Wildcard ACM cert (`*.bankapp.example.com`) with Route 53 DNS validation
- IAM/IRSA roles for pod-level DynamoDB and S3 access
- CircleCI OIDC provider and role for ECR push and EKS deploy
- S3 buckets for Tempo trace storage and frontend assets
- Secrets Manager entries for JWT keypair
- Cilium CNI (with Hubble relay + UI) and AWS Load Balancer Controller via Helm
- CloudWatch observability EKS addon

## Phase 2 — Kubernetes Manifests

Replaces `dev-kubernetes-manifests/` with a new `kubernetes-manifests/` directory:

- Single `ingress.yaml` with 3 host rules (app, grafana, hubble)
- `deployment.yaml` and `service.yaml` for all 7 services, with IRSA service accounts and DynamoDB env config
- `config.yaml` ConfigMap for AWS region and table names; ExternalSecret CRs for JWT keys
- Observability Helm values for Grafana, Tempo (S3-backed), Prometheus, and an OTEL Collector DaemonSet
- Kustomize `dev/` and `prod/` overlays for replica counts, resource limits, and image tags

## Phase 3 — Go Service Rewrites

Rewrites the 3 Java services in Go:

- **balancereader** — `GET /balances/{accountId}` from DynamoDB Balances table
- **ledgerwriter** — `POST /transactions` with atomic DynamoDB TransactWriteItems (balance + transaction)
- **transactionhistory** — `GET /transactions/{accountId}` with pagination, sorted descending by timestamp

Each service includes: `main.go`, `go.mod`, unit tests, JWT validation middleware (RS256), OTEL instrumentation, and a multi-stage Dockerfile (`golang:1.22-alpine` -> `distroless/static-debian12`).

## Phase 4 — Python DynamoDB Migration

Updates Python services to replace PostgreSQL with DynamoDB:

- **userservice** — swaps `psycopg2`/SQLAlchemy for `boto3`; reads table name from `DYNAMODB_USERS_TABLE`
- **contacts** — swaps `psycopg2` for `boto3`; reads table name from `DYNAMODB_CONTACTS_TABLE`
- Both services drop `psycopg2-binary` and add `boto3` to `requirements.txt`
- **frontend** — minor cleanup to remove any leftover database connection references

## Phase 5 — CircleCI Pipeline

Rewrites `.circleci/config.yml` for the new stack:

- OIDC-based AWS authentication (no Vault, no static credentials)
- Jobs: `go-lint`, `go-test`, `python-checkstyle`, `python-test`, `build-and-push` (ECR), `terraform-plan`, `terraform-apply`, `deploy-app`, `deploy-observability`, `e2e-test`, prod variants
- Skaffold builds and pushes all 7 images to ECR
- Terraform plan posted as PR comment; apply runs on `main` only
- Cypress e2e against `https://app.dev.{domain}` gates prod promotion

## Phase 6 — Cleanup

Removes legacy files and directories no longer needed:

- `src/accounts-db/`, `src/ledger-db/` — replaced by DynamoDB
- `src/ledgermonolith/` — not deployed in new architecture
- `dev-kubernetes-manifests/`, `istio-manifests/` — replaced by `kubernetes-manifests/`
- `pom.xml`, `mvnw`, `mvnw.cmd`, `.mvn/` — no more Java/Maven
- `.circleci/vault/`, `extras/jwt/` — secrets move to AWS Secrets Manager
- Argo Rollouts virtual service files

Updates: `skaffold.yaml` (7 images, ECR targets, Go Dockerfiles), `README.md`, `.gitignore`.
