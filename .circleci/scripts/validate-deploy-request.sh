#!/usr/bin/env bash

set -euo pipefail

action=${1:-}
artifact_ref=${2:-}

case "${action}" in
  redeploy|rollback)
    ;;
  *)
    echo "Unsupported deploy action: '${action}' - valid actions are: redeploy, rollback" >&2
    exit 1
    ;;
esac

if [[ -z "${artifact_ref}" ]]; then
  echo "artifact_ref must not be empty" >&2
  exit 1
fi

# Strict allowlist: anything outside these characters (shell metacharacters,
# quotes, whitespace, newlines) is rejected before the ref reaches any command.
if [[ ! "${artifact_ref}" =~ ^[A-Za-z0-9:._@/-]+$ ]]; then
  echo "artifact_ref contains invalid characters: only non-empty values matching ^[A-Za-z0-9:._@/-]+\$ are allowed (no whitespace, quotes or shell metacharacters)" >&2
  exit 1
fi

echo "Validated ${action} request for ${artifact_ref}"
