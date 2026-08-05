# Deploy-only and rollback workflow design

## Goal

Prototype the workflow Freshpaint described: operators can redeploy or roll back an
already-built immutable artifact without rerunning the main test suite. The escape
hatch remains deliberate and auditable rather than turning test bypass into the
normal deployment path.

## Pipeline interface

Add three pipeline parameters:

- `deploy_only` (boolean, default `false`) selects the emergency deployment path.
- `deploy_action` (string, default `redeploy`) accepts `redeploy` or `rollback`.
- `artifact_ref` (string, default empty) identifies the exact existing image,
  package, or release to deploy.

The normal `main` workflow runs only when `run_full_suite` is true and
`deploy_only` is false. The new `deploy-only` workflow runs only when
`deploy_only` is true. These conditions make the paths mutually exclusive.

## Workflow

The deploy-only path contains four jobs:

1. `validate-deploy-request` rejects an empty artifact reference or an unsupported
   action before an operator waits at an approval gate.
2. `approve-deploy-only` is a manual approval job. CircleCI records who approved
   the deployment.
3. `deploy-existing-artifact` simulates promoting the supplied immutable artifact.
   It does not check out source, compile code, or run the normal test jobs. A
   project-scoped `serial-group` prevents overlapping production deployments.
4. `verify-deployed-artifact` runs lightweight post-deploy smoke checks and verifies
   that the deployed reference matches the requested reference.

The prototype writes a deployment manifest to a workspace and stores it as an
artifact. This makes the action, artifact reference, pipeline, actor, and timestamp
visible without touching real infrastructure. In production, the mock command
would be replaced by the existing deployment command.

## Safety properties

- The workflow deploys an artifact that already exists; it never rebuilds a prior
  commit during rollback.
- Tests are skipped only when the caller explicitly sets `deploy_only: true`.
- Manual approval remains mandatory for both redeploy and rollback.
- Invalid or missing input fails before deployment.
- Deployment serialization prevents two operators from racing changes into the
  same environment.
- Smoke checks remain after deployment because skipping pre-deploy tests should
  not remove verification of the live target.

CircleCI pipeline parameters are strings rather than enums, so action validation
must happen in a job. Artifact existence would also be checked against the real
registry or artifact store in a production implementation.

## Trigger examples

Normal CI uses the defaults and runs the main workflow. A deploy-only trigger sends
pipeline parameters equivalent to:

```json
{
  "deploy_only": true,
  "deploy_action": "rollback",
  "artifact_ref": "sha256:existing-immutable-artifact"
}
```

Changing `deploy_action` to `redeploy` promotes the same supplied version again.

## Verification

1. Validate the config with the CircleCI CLI.
2. Confirm a default pipeline selects `main` and not `deploy-only`.
3. Confirm a deploy-only pipeline selects only the four deployment-path jobs.
4. Confirm an empty `artifact_ref` fails request validation.
5. Confirm an unsupported `deploy_action` fails request validation.
6. Approve a valid rollback and verify the deployment manifest contains the exact
   supplied artifact reference.
7. Verify smoke checks run after deployment and normal test jobs do not.

Local Maven baseline tests are currently unavailable because the host has no Java
runtime. The change is isolated to CircleCI configuration and will be verified
through config validation and sandbox pipelines.
