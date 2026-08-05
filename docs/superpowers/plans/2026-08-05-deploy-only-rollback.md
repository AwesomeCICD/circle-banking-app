# Deploy-only and Rollback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a safe CircleCI sandbox workflow that deploys an existing immutable artifact without running the normal test suite.

**Architecture:** Pipeline parameters make the normal and deploy-only workflows mutually exclusive. A standalone shell validator rejects bad requests, then manual approval, a serialized mock deployment, and a smoke check demonstrate the production flow without touching infrastructure.

**Tech Stack:** CircleCI 2.1 configuration, POSIX shell, CircleCI CLI

---

### Task 1: Test and implement request validation

**Files:**
- Create: `.circleci/tests/deploy-only-workflow-test.sh`
- Create: `.circleci/scripts/validate-deploy-request.sh`

- [ ] **Step 1: Write the failing validator tests**

Create `.circleci/tests/deploy-only-workflow-test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATOR="${ROOT}/.circleci/scripts/validate-deploy-request.sh"

"${VALIDATOR}" redeploy sha256:abc123
"${VALIDATOR}" rollback release-2026-08-05

if "${VALIDATOR}" redeploy ""; then
  echo "expected an empty artifact_ref to fail" >&2
  exit 1
fi

if "${VALIDATOR}" destroy sha256:abc123; then
  echo "expected an unsupported deploy_action to fail" >&2
  exit 1
fi
```

- [ ] **Step 2: Run the test and confirm the expected failure**

Run: `bash .circleci/tests/deploy-only-workflow-test.sh`

Expected: FAIL because `.circleci/scripts/validate-deploy-request.sh` does not exist.

- [ ] **Step 3: Implement the minimal validator**

Create `.circleci/scripts/validate-deploy-request.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

action="${1:-}"
artifact_ref="${2:-}"

case "${action}" in
  redeploy|rollback) ;;
  *)
    echo "deploy_action must be 'redeploy' or 'rollback'; got '${action}'" >&2
    exit 1
    ;;
esac

if [[ -z "${artifact_ref}" ]]; then
  echo "artifact_ref must identify an existing immutable artifact" >&2
  exit 1
fi

echo "Validated ${action} request for ${artifact_ref}"
```

- [ ] **Step 4: Run the validator tests**

Run: `bash .circleci/tests/deploy-only-workflow-test.sh`

Expected: PASS with validation messages; the two intentionally invalid invocations exit non-zero.

### Task 2: Test and implement mutually exclusive workflows

**Files:**
- Modify: `.circleci/tests/deploy-only-workflow-test.sh`
- Modify: `.circleci/config.yml:3-9`
- Modify: `.circleci/config.yml:28-375`

- [ ] **Step 1: Add failing processed-config assertions**

Append to `.circleci/tests/deploy-only-workflow-test.sh`:

```bash
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

circleci config process "${ROOT}/.circleci/config.yml" \
  > "${tmp_dir}/default.yml"

cat > "${tmp_dir}/deploy-only-params.json" <<'JSON'
{
  "deploy_only": true,
  "deploy_action": "rollback",
  "artifact_ref": "sha256:abc123"
}
JSON

circleci config process "${ROOT}/.circleci/config.yml" \
  --pipeline-parameters "${tmp_dir}/deploy-only-params.json" \
  > "${tmp_dir}/deploy-only.yml"

grep -q "java-test-and-code-cov" "${tmp_dir}/default.yml"
if grep -q "validate-deploy-request" "${tmp_dir}/default.yml"; then
  echo "default pipeline unexpectedly contains deploy-only jobs" >&2
  exit 1
fi

grep -q "validate-deploy-request" "${tmp_dir}/deploy-only.yml"
grep -q "approve-deploy-only" "${tmp_dir}/deploy-only.yml"
grep -q "deploy-existing-artifact" "${tmp_dir}/deploy-only.yml"
grep -q "verify-deployed-artifact" "${tmp_dir}/deploy-only.yml"
if grep -q "java-test-and-code-cov" "${tmp_dir}/deploy-only.yml"; then
  echo "deploy-only pipeline unexpectedly contains normal test jobs" >&2
  exit 1
fi
```

- [ ] **Step 2: Run the test and confirm the expected failure**

Run: `bash .circleci/tests/deploy-only-workflow-test.sh`

Expected: FAIL because the pipeline parameters and deploy-only jobs are absent.

- [ ] **Step 3: Add the pipeline parameters**

Add under `parameters` in `.circleci/config.yml`:

```yaml
  deploy_only:
    type: boolean
    default: false
  deploy_action:
    type: string
    default: redeploy
  artifact_ref:
    type: string
    default: ""
```

- [ ] **Step 4: Add validation, deployment, and verification jobs**

Add three jobs before `workflows`:

```yaml
  validate-deploy-request:
    executor: docker-builder
    steps:
      - checkout
      - run:
          name: Validate deploy-only request
          command: .circleci/scripts/validate-deploy-request.sh "<< pipeline.parameters.deploy_action >>" "<< pipeline.parameters.artifact_ref >>"

  deploy-existing-artifact:
    executor: docker-builder
    serial-group: << pipeline.project.slug >>/production-deploy
    steps:
      - run:
          name: Deploy existing immutable artifact
          command: |
            mkdir -p /tmp/deployment
            {
              echo "action=<< pipeline.parameters.deploy_action >>"
              echo "artifact_ref=<< pipeline.parameters.artifact_ref >>"
              echo "pipeline_id=${CIRCLE_WORKFLOW_ID}"
              echo "deployed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
            } | tee /tmp/deployment/manifest.txt
      - persist_to_workspace:
          root: /tmp/deployment
          paths:
            - manifest.txt
      - store_artifacts:
          path: /tmp/deployment/manifest.txt

  verify-deployed-artifact:
    executor: docker-builder
    steps:
      - attach_workspace:
          at: /tmp/deployment
      - run:
          name: Verify deployed artifact and smoke checks
          command: |
            grep -Fx "artifact_ref=<< pipeline.parameters.artifact_ref >>" /tmp/deployment/manifest.txt
            echo "Checking frontend health endpoint..."
            echo "Checking ledgerwriter transaction validation..."
            echo "Checking userservice auth endpoint..."
            echo "Smoke tests passed for << pipeline.parameters.artifact_ref >>"
```

- [ ] **Step 5: Make workflow selection mutually exclusive**

Replace the `main` workflow condition with:

```yaml
    when:
      and:
        - << pipeline.parameters.run_full_suite >>
        - not: << pipeline.parameters.deploy_only >>
```

Add the deploy-only workflow:

```yaml
  deploy-only:
    when: << pipeline.parameters.deploy_only >>
    jobs:
      - validate-deploy-request
      - approve-deploy-only:
          type: approval
          requires:
            - validate-deploy-request
      - deploy-existing-artifact:
          requires:
            - approve-deploy-only
      - verify-deployed-artifact:
          requires:
            - deploy-existing-artifact
```

- [ ] **Step 6: Run focused tests and config validation**

Run:

```bash
bash .circleci/tests/deploy-only-workflow-test.sh
circleci config validate .circleci/config.yml
git diff --check
```

Expected: all commands exit zero. The default processed config contains normal tests only; the deploy-only processed config contains only the deployment path.

### Task 3: Remote runtime verification

**Files:**
- No source changes expected

- [ ] **Step 1: Check Chunk authentication and active sidecar**

Run:

```bash
chunk auth status
chunk sidecar current
```

Expected: CircleCI authentication is configured. If no sidecar is active, use the repository's configured snapshot or report that sidecar setup is required.

- [ ] **Step 2: Sync and run the focused test remotely when available**

Run:

```bash
chunk sidecar sync
chunk validate --remote --cmd "bash .circleci/tests/deploy-only-workflow-test.sh"
```

Expected: PASS on Linux. If no configured sidecar is available, use CircleCI config validation as the prototype verification and report the environment limitation.
