# CCI Bank Corp

**CCI Bank Corp** is a sample HTTP-based web app that simulates a bank's payment processing network, allowing users to create artificial bank accounts and complete transactions.

We (CCI Field Eng. Team) forked it from [Google's Bank of Anthos project](https://github.com/GoogleCloudPlatform/bank-of-Aion/)
, chosen for it's multi-language monorepo structure with various microservices.


## Screenshots

| Sign in                                                                                                        | Home                                                                                                    |
| ----------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| [![Login](./docs/login.png)](./docs/login.png) | [![User Transactions](./docs/transactions.png)](./docs/transactions.png) |


## Service architecture

![Architecture Diagram](./docs/architecture.png)

| Service                                          | Language      | Description                                                                                                                                  |
| ------------------------------------------------ | ------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| [frontend](./src/frontend)                       | Python        | Exposes an HTTP server to serve the website. Contains login page, signup page, and home page.                                                |
| [ledger-writer](./src/ledgerwriter)              | Java          | Accepts and validates incoming transactions before writing them to the ledger.                                                               |
| [balance-reader](./src/balancereader)            | Java          | Provides efficient readable cache of user balances, as read from `ledger-db`.                                                                |
| [transaction-history](./src/transactionhistory)  | Java          | Provides efficient readable cache of past transactions, as read from `ledger-db`.                                                            |
| [ledger-db](./src/ledger-db)                     | PostgreSQL | Ledger of all transactions. Option to pre-populate with transactions for demo users.                                                         |
| [user-service](./src/userservice)                | Python        | Manages user accounts and authentication. Signs JWTs used for authentication by other services.                                              |
| [contacts](./src/contacts)                       | Python        | Stores list of other accounts associated with a user. Used for drop down in "Send Payment" and "Deposit" forms. |
| [accounts-db](./src/accounts-db)                 | PostgreSQL | Database for user accounts and associated data. Option to pre-populate with demo users.                                                      |
| [loadgenerator](./src/loadgenerator)             | Python/Locust | Continuously sends requests imitating users to the frontend. Periodically creates new accounts and simulates transactions between them.      |


## Quickstart (SE on CERA)


### Concepts
 The credentials are comprised of a CA certificate and a secret token, pulled from CERA vault (Hashicorp). (See reference-architecture).  Those are provided to Dev team as a CCI Context for each environment via OIDC claims in vault.

 The application must define what role & `VAULT_ADDRESS` to connect to, which with set the appropriate environment's secrets.

 Available Roles (in any CERA Region)
 - cba-prod
 - cba-dev

 The appropriate deployment jobs access a `K8_TOKEN` and `K8_CERT` that is used to define connection along with the URL, CLUSTER_NAME, and NAMESPACE




1. **Deploy CCI Bank Corp to the cluster.**

**Yes SE team, we use Skaffold here, see config.yml and [`developmentmd`](docs/development.md) for more**

```
skaffold run --tag=build-local --default-repo=docker.nexus.cera.circleci-capitalone-demo.com
```

5. **Wait for the Pods to be ready.**

```
kubectl get pods
```

After a few minutes, you should see the Pods in a `Running` state:

```
NAME                                  READY   STATUS    RESTARTS   AGE
accounts-db-6f589464bc-6r7b7          1/1     Running   0          99s
balancereader-797bf6d7c5-8xvp6        1/1     Running   0          99s
contacts-769c4fb556-25pg2             1/1     Running   0          98s
frontend-7c96b54f6b-zkdbz             1/1     Running   0          98s
ledger-db-5b78474d4f-p6xcb            1/1     Running   0          98s
ledgerwriter-84bf44b95d-65mqf         1/1     Running   0          97s
loadgenerator-559667b6ff-4zsvb        1/1     Running   0          97s
transactionhistory-5569754896-z94cn   1/1     Running   0          97s
userservice-78dc876bff-pdhtl          1/1     Running   0          96s
```

6. **Access the web frontend in a browser** using the frontend's external IP.

```
kubectl get service frontend | awk '{print $4}'
```

Visit `https://EXTERNAL_IP` to access your instance of CCI Bank Corp.

## Additional deployment options

- **Workload Identity**: [See these instructions.](./docs/workload-identity.md)
- **Istio**: Apply `istio-manifests/` to your cluster to access the frontend through the IngressGateway.
- **Java Monolith (VM)**: We provide a version of this app where the three Java microservices are coupled together into one monolithic service, which you can deploy inside a VM (eg. Google Compute Engine). See the [ledgermonolith](./src/ledgermonolith) directory.

## Troubleshooting

See the [troubleshooting guide](./docs/troubleshooting.md) for resolving common problems.

## Development

See the [development guide](./docs/development.md) to learn how to run and develop this app locally.


## Deploy & Release Integration

Argo Rollouts is enabled, for these clusters.

Frontend `Deployment` was replaced with a `Rollout` including steps.

Status: you can use `kubectl argo rollouts get rollout frontend-rollout -n cba-dev -w` to see status.

All components tag app name and version. (Version Label is applied by skaffold `-l` flag directly.)

`kustomize.yaml` is used to apply build specific data (id, pipeline, etc) as annotations to Frontend only currently.