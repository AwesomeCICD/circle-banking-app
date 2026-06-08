# CCI Bank Corp — AWS Demo Application

Polyglot microservices banking demo for CircleCI + Amazon EKS. Python frontend/services, Go ledger services, DynamoDB, ALB ingress, Grafana observability.

**Target cluster:** `fe-runner-cluster` (us-east-1)

## Architecture

See [docs/proposed-architecture.md](docs/proposed-architecture.md) for diagrams.

| Endpoint | Purpose |
|----------|---------|
| `app.dev.{domain}` | Banking UI |
| `grafana.dev.{domain}` | Traces + metrics dashboards |
| `hubble.dev.{domain}` | Network flow visualization (if Cilium/Hubble installed) |

## Repo layout

```
terraform/                 # AWS: DynamoDB, ECR, IAM, Route53, ACM, ALB controller
kubernetes-manifests/      # Kustomize base + dev/prod overlays
src/                       # 7 services (3 Go, 3 Python, 1 load generator)
scripts/                   # DynamoDB seed, observability Helm install
.circleci/config.yml       # CI/CD: test → docker push → deploy
```

**Skaffold removed** — CircleCI builds with `docker build/push` and deploys with `kubectl apply` + Kustomize. Easier to explain in customer demos.

## Quick start (local)

```bash
# Go services
cd src/balancereader && go test ./...

# Python services
cd src/userservice && pip install -r requirements.txt && pytest tests
```

## Deploy prerequisites

1. EKS cluster `fe-runner-cluster` with AWS Load Balancer Controller
2. CircleCI OIDC context `aws-oidc-dev` with `AWS_ROLE_ARN`, `AWS_APP_ROLE_ARN`, `ACM_CERT_ARN`
3. Terraform state bucket + `terraform.tfvars` (copy from `terraform/terraform.tfvars.example`)
4. JWT keys in Secrets Manager (`bankcorp/jwt-private-key`, `bankcorp/jwt-public-key`)

## Pipeline flow

1. **Lint & test** — Go + Python
2. **build-and-push** — 7 images to ECR (`docker build`, no Skaffold)
3. **terraform-plan/apply** — AWS resources (main branch for apply)
4. **deploy-app** — `kubectl apply` via Kustomize to `fe-runner-cluster`
5. **deploy-observability** — Helm: kube-prometheus-stack + Tempo
6. **e2e-test** — Cypress against `app.dev.{domain}`

## Configuration

CircleCI pipeline parameters in `.circleci/config.yml`:

| Parameter | Default |
|-----------|---------|
| `eks_cluster_name` | `fe-runner-cluster` |
| `aws_region` | `us-east-1` |
| `k8s_namespace` | `bankcorp` |
| `domain` | `bankapp.example.com` |

## Demo login

After seeding (`scripts/seed-dynamodb.py` runs post-terraform-apply):

- Username: `testuser`
- Password: `circleci`

Implementation guide for agents: [CLAUDE.md](CLAUDE.md)
