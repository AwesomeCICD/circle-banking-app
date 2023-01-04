# Vault Setup



See https://github.com/AwesomeCICD/cera-services/blob/main/vault/OIDC.md


## Example


vault write auth/jwt/role/boa-dev-deploy -<<EOF
{
  "role_type": "jwt",
  "user_claim": "sub",
  "user_claim_json_pointer": "true",
  "bound_claims": {
    "oidc.circleci.com/project-id": "788dd296-2fca-4718-82f8-07db1637a58e",
    "oidc.circleci.com/context-ids": [ "7cf67bf2-cf99-4cc7-8ae5-a0daf86ae02b" ]
  },
  "policies": ["boa-dev-deploy"],
  "ttl": "10m"
}
EOF