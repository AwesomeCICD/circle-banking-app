# Circle Banking App

Polyglot microservices banking demo for CircleCI + Amazon EKS.

**Live app:** [https://app.dev.fieldeng-sphereci.com](https://app.dev.fieldeng-sphereci.com)

| Endpoint | URL |
|----------|-----|
| Banking UI | https://app.dev.fieldeng-sphereci.com |
| Grafana | https://grafana.dev.fieldeng-sphereci.com |

**Cluster:** `fe-runner-cluster` (us-east-1) — architecture docs in [docs/proposed-architecture.md](docs/proposed-architecture.md).

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
4. JWT keys in Secrets Manager (`circle-banking-app/jwt-private-key`, `circle-banking-app/jwt-public-key`)

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
| `k8s_namespace` | `circle-banking-app` |
| `domain` | `fieldeng-sphereci.com` |

## Demo login

After seeding (`scripts/seed-dynamodb.py` runs post-terraform-apply):

- Username: `testuser`
- Password: `circleci`

Implementation guide for agents: [CLAUDE.md](CLAUDE.md)
