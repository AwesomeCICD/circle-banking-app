# DEMO.md — circle-banking-app (baseline)

| | |
|---|---|
| **Catalog use cases** | 2 Platform Engineering & Golden Path · 3 Security / Supply Chain · 7 Containers & Microservices |
| **Owners** | UC2, UC7: Derry Bradley · UC3: Vijay Pandian |
| **Branch** | `cera-refactor` (becomes `main` when merged) |
| **Status** | DRAFT — talk tracks written from the branch, not yet run at demo triage |
| **Live app** | https://circle-banking-app.namer.fieldeng-sphereci.com |
| **Grafana** | https://grafana.namer.fieldeng-sphereci.com |
| **Cluster** | EKS `fe-cera-v2-namer`, us-east-1, namespace `circle-banking-app` |

The baseline is the demo to run cold: booths, first calls and discovery. It's a 7-service polyglot banking app ("CCI Bank Corp"): 3 Go, 3 Python and a Locust load generator. One pipeline tests it, provisions AWS with Terraform, builds 7 images to ECR, deploys to EKS with Kustomize, smoke-tests the live endpoints and promotes to production.

---

## 1. Pre-flight (10 minutes before)

- [ ] **Last `main` workflow on `cera-refactor` is green.** If it's red, go to section 7 first.
- [ ] **App loads and you can log in.** Demo credentials are in Secrets Manager under `AwesomeCICD/circle-banking-app/secrets` (`demo_username` / `demo_password`).
- [ ] **Grafana loads and you can log in.** The admin password is `grafana_admin_password` in the same secret.
- [ ] **Laptop kit works.** Run `circleci version` and check that the MCP server is connected.
- [ ] **Tabs are open:**
  - the pipeline list
  - the last green workflow graph
  - `.circleci/config.yml` on GitHub
  - the live app
  - Grafana
- [ ] **Optional live trigger:** have a harmless one-line change ready on a branch so you can push it and let the audience watch the pipeline run.

---

## 2. What the pipeline actually does

One workflow, `main`:

```
go-checkstyle ─┐
go-test ───────┤  (15x parallel, split by timings)
python-checkstyle
python-test ───┤  (15x parallel, split by timings)
               ▼
circle-banking-app.deploy-ecr     ← job group, serial-group per project
  tf-plan → tf-apply ─┬→ build-and-push-to-ecr-{7 services} (parallel) → deploy-dev
                      └→ deploy-o11y (Helm: kube-prometheus-stack, Beyla)
               ▼
dns-apply      ← reads live ALB DNS from the workspace, writes Route 53 via Terraform
               ▼
e2e-test       ← 15x parallel curl probes of app + Grafana, JUnit results
               ▼
Deploy Production  ← prod Kustomize overlay, cera-refactor branch only
```

**Features you can point at in `config.yml`:**

| Feature | Where to point |
|---|---|
| OIDC to AWS, no stored keys | `commands.aws-setup` → `aws-cli/setup` with `role_arn` |
| Reusable commands | `aws-setup`, `install-kubectl`, `install-kustomize`, `configure-kubeconfig` |
| Pipeline parameters | registry, cluster, region, namespace, domain, role ARNs |
| Parameterized jobs | `build-and-push-to-ecr` (`service`), `deploy-app` (`overlay`) |
| Job groups | `job-groups.deploy-ecr` |
| Serial groups | `serial-group: << pipeline.project.slug >>/deploy-ecr` |
| Timing-based test splitting | `go-test`, `python-test`, `e2e-test`, each with `parallelism: 15` and `circleci tests split --split-by=timings` |
| Test results and artifacts | `store_test_results` / `store_artifacts` in all three test jobs |
| Workspaces carrying live infra outputs | `deploy-app` persists `alb_dns` / `alb_zone`, and `dns-apply` attaches them |
| Branch filters | `Deploy Production` is set to `only: cera-refactor` |
| Commit → image traceability | images are tagged `${CIRCLE_SHA1:0:7}` |

---

## 3. Talk track A: cold opener (5 min, any audience)

Use at a booth, on a first call, or as the lead-in to any other track.

| Show | Say |
|---|---|
| **Live app.** Log in, open the account home. | "This is CCI Bank: seven microservices in two languages on EKS, backed by DynamoDB. It's a working app, not a slide." |
| **Last green workflow graph.** | "Every commit takes this path: lint and test, provision AWS with Terraform, build seven containers, deploy, test the live system, then promote to production. It's one pipeline and one config file." |
| **Test jobs.** Hover over the 15 parallel nodes. | "Tests are split across machines using real timing data from earlier runs, so each machine finishes at about the same time. As the suite grows, you add parallelism instead of waiting longer." |
| **`deploy-ecr` group.** Expand it. | "Everything that touches infrastructure is grouped and runs one at a time. If two developers merge at the same moment, the second run waits instead of colliding." |
| **`e2e-test` → Tests tab.** | "Before production, we probe the live endpoints. Failures show up here as test results, not buried in a log." |

**Close with a discovery question:** "Which part of that looks most like your pipeline today, and which part is the most painful?" Their answer tells you whether to go to track B, C or D next.

---

## 4. Talk track B: Containers & Microservices, registry → k8s (UC7, ~15 min)

**Audience:** platform, DevOps and SRE teams running Kubernetes.

**Story:** "Seven services, one repo, one pipeline, into a real EKS cluster, without a CD tool bolted on the side."

1. **Monorepo and services** (2 min). Show `src/`.
   - *Say:* "Three Go services, three Python services and a load generator. The Go services were rewritten from Java and now ship as static binaries on distroless images, using a plain multi-stage Dockerfile. The pipeline doesn't care which language a service is in."
2. **Build fan-out** (3 min). Show `build-and-push-to-ecr` and the 7 parallel jobs in the graph.
   - *Say:* "One job definition with a `service` parameter becomes seven parallel builds. Each image is tagged with the commit SHA, so any pod traces back to the exact commit that built it."
   - *Show:* the ECR login that uses the OIDC session. "No AWS keys are stored in CircleCI."
3. **Deploy with Kustomize** (4 min). Show the `deploy-app` steps.
   - *Say:* "Plain `kustomize` and `kubectl`, nothing proprietary. We set image tags, render the overlay, apply, then wait on each rollout. Dev and prod are overlays of the same base. Prod points at its own DynamoDB tables and runs two frontend replicas."
   - *Show:* `kubernetes-manifests/overlays/prod/kustomization.yaml`.
4. **Live infra outputs flow downstream** (2 min). Show `deploy-dev` → `dns-apply`.
   - *Say:* "The load balancer address doesn't exist until the deploy creates it. We capture it, pass it through a workspace, and the next job writes DNS with Terraform. Everything is wired inside the pipeline, with no hand-offs."
5. **Verify, then promote** (2 min). Show `e2e-test` results, then `Deploy Production`.
   - *Say:* "Production only deploys after the live system passes its checks, and only from the release branch."
6. **Observability** (2 min, optional). Show Grafana.
   - *Say:* "The same pipeline installs Prometheus, Grafana and Beyla, which is eBPF auto-instrumentation with no code changes. Your observability ships with your app."

**Discovery questions:**
- "How many services, and how many pipelines do they use today?"
- "Where do Helm, Kustomize or Argo sit in your deploy path?"
- "How do you trace a running pod back to the commit that built it?"

---

## 5. Talk track C: Platform Engineering & Golden Path (UC2, ~15 min)

**Audience:** platform team leads and engineering managers standardizing CI across teams.

**Story:** "The platform team defines the paved road once. Every service team gets it by default."

1. **Reusable building blocks** (3 min). Show the `commands:` block.
   - *Say:* "AWS login, kubectl, kustomize and kubeconfig are each defined once and reused in every job. Change it here and every job picks it up. Package these as an orb and every repo in the org gets the same thing." Bridge to `platform-team-toolkit` if the audience wants depth.
2. **Parameters as the contract** (2 min). Show `parameters:`.
   - *Say:* "Cluster, region, namespace, domain and roles are all parameters. Point the same pipeline at a new region or account without editing jobs."
3. **Job groups** (3 min). Show `job-groups.deploy-ecr`.
   - *Say:* "The platform team owns the deploy path as one named unit: plan, apply, build, deploy. Service teams call it by name instead of copying 200 lines of YAML."
4. **Serial groups as a guardrail** (4 min). Show the `serial-group` key, then trigger two pipelines back to back if you can.
   - *Say:* "Terraform state and the cluster are shared, so the whole group runs one at a time across the project. The second run queues instead of racing. That's a platform guarantee the service team never has to think about."
5. **Branch policy in config** (2 min). Show the `filters` on `Deploy Production`.
   - *Say:* "Which branches can reach production is written in code and reviewed like code."
6. **Close** (1 min).
   - *Say:* "Nothing here is custom tooling. It's CircleCI config a platform team can own, version and roll out."

**Discovery questions:**
- "How many teams maintain their own pipeline config today?"
- "What happens when two deploys hit shared infra at once?"
- "How do you roll out a CI change to every repo?"

---

## 6. Talk track D: Security / DevSecOps / Supply Chain (UC3, ~10 min) — DRAFT for Vijay

**Audience:** security, compliance and platform security.

**Story:** "No long-lived credentials anywhere in the pipeline, and every artifact traceable to a commit."

1. **OIDC, not keys** (4 min). Show `aws-setup`.
   - *Say:* "Each job exchanges a short-lived CircleCI OIDC token for an AWS role. Nothing to rotate, nothing to leak. The session name carries the workflow ID and job name, so CloudTrail shows exactly which pipeline did what."
2. **Secrets stay in the secret store** (3 min). Show the JWT bootstrap and demo-credentials steps in `deploy-app`.
   - *Say:* "The app's signing keys are generated on first run and kept in AWS Secrets Manager. They're pulled at deploy time and never written to the repo or the CircleCI UI."
3. **Traceability and quality gates** (3 min).
   - *Say:* "Images are tagged with the commit SHA. `go vet`, `staticcheck` and `pylint` gate every commit, and Go tests run with the race detector."

**Vijay to decide:** this branch has no image scanning, SBOM, signing or approval gate yet. Either add a scanner job (snyk-demo is listed in the catalog) or keep this track to credentials and traceability. Don't claim scanning until it's in the pipeline.

**Discovery questions:**
- "How are cloud credentials stored in CI today, and who rotates them?"
- "Could you prove which commit is running in production right now?"

---

## 7. If it breaks on stage

| Symptom | Likely cause | Recovery line |
|---|---|---|
| Second pipeline sits in "queued" on `deploy-ecr` | The serial group is doing its job | "That's the guardrail from earlier: it's waiting its turn." Use it. |
| `deploy-o11y` fails | Grafana password is still `PLACEHOLDER` in Secrets Manager | Show the green deploy path, then fix the secret after the call |
| `e2e-test` fails | ALB/DNS not propagated yet (it retries 20 times, 15s apart) | "This is exactly why the check runs before prod." Open the Tests tab. |
| App is down | Cluster or deploy issue | Walk the last green workflow instead. Don't live-debug. |

---

## 8. Don't say (not in this branch)

The catalog page still describes the old CERA build. On `cera-refactor`:

- **No Vault.** Secrets are in AWS Secrets Manager, and CI uses OIDC straight to AWS IAM.
- **No Java.** The backends are Go now.
- **No Docker layer caching.** `setup_remote_docker` is used without DLC.
- **No matrix jobs.** Fan-out uses parameterized jobs in a job group.
- **No progressive or canary deploy.** Argo Rollouts was removed, and deploys are standard rolling updates. For progressive delivery, go to `dr-demo` (UC5).
- **No path filtering.** Every push runs every job.
- **No Hubble/Cilium or Tempo traces.** They're in the proposed architecture but not deployed. Tempo only installs if `TEMPO_TRACES_BUCKET` is set, and the config doesn't set it.
- **No real Python unit coverage.** `python-test` runs `test_ci_shard_*.py` files, which are small synthetic tests there to demonstrate splitting. Frame the story as "test splitting", not "test coverage".
- **No CircleCI deploy markers or release tracking.** That's `dr-demo` too.

---

## 9. Fix before calling this catalog-ready

These showed up while writing the talk tracks. None of them blocks a demo today, but each is a question someone will eventually ask.

1. **Dev and prod share one namespace and one set of hostnames.** Both overlays deploy to `circle-banking-app` on the same cluster with identical ingress hosts, so `Deploy Production` overwrites dev. Check that the `-prod` DynamoDB tables exist. `dynamodb.tf` creates tables for one `var.environment` only.
2. **Rollout failures are swallowed.** `kubectl rollout status ... || kubectl describe` keeps the job green even when a rollout fails. Fail the job instead, so the pipeline tells the truth.
3. **App pods use the CI role through IRSA.** The config says a least-privilege role is planned. Fix this before any security audience sees it.
4. **Production has no approval gate.** Adding a `type: approval` job before `Deploy Production` strengthens tracks C and D.
5. **Terraform runs with `-lock=false`.** It's safe only because of the serial group. Say that explicitly (it's a good talking point), or re-enable locking.
6. **Unpinned installs.** `staticcheck@latest` and the Helm install script piped from `main` over `curl | bash` will be flagged by security audiences.
7. **`curl -k` in e2e.** TLS verification is skipped even though an ACM cert exists.
8. **Update the Confluence catalog page.**
   - The project description (Java + Python, Vault, DLC, progressive deploy) is stale.
   - The known gap "Baseline cannot deploy until the CERA replacement exists" is resolved by this branch once it merges.
