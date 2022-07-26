![Continuous Integration](https://github.com/GoogleCloudPlatform/bank-of-Aion/workflows/Continuous%20Integration%20-%20Main/Release/badge.svg)

# Bank of Aion

**Bank of Aion** is a sample HTTP-based web app that simulates a bank's payment processing network, allowing users to create artificial bank accounts and complete transactions.

We forked it from Google, chosen for it's multi-language monorepo structure with various microservices.


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
 The credentials are comprised of a CA certificate and a secret token, pulled from K8s cluster. (See reference-architecture).  Those are provided to Dev team as a CCI Context for each environment.
 - `cera-boa-dev` a dev context
 - `cera-boa-prod` a prod context
 The appropriate deployment jobs access a `K8_TOKEN` and `K8_CERT` that is used to define connection along with the URL, CLUSTER_NAME, and NAMESPACE

We can use namespaces to represent the distinct environments.





1. Modify the Namespace to avoid collision OR target a non shared cluster
(CI process will handle this)

2. Ensure you have access to EKS cluster via AWS SSO or K8s ServiceAccount (ci process uses latter)



4. **Deploy Bank of Aion to the cluster.**

```
kubectl apply -f ./extras/jwt/jwt-secret.yaml
kubectl apply -f ./kubernetes-manifests
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

Visit `https://EXTERNAL_IP` to access your instance of Bank of Aion.

## Additional deployment options

- **Workload Identity**: [See these instructions.](./docs/workload-identity.md)
- **Cloud SQL**: [See these instructions](./extras/cloudsql) to replace the in-cluster databases with hosted Google Cloud SQL.
- **Multi Cluster with Cloud SQL**: [See these instructions](./extras/cloudsql-multicluster) to replicate the app across two regions using GKE, Multi Cluster Ingress, and Google Cloud SQL.
- **Istio**: Apply `istio-manifests/` to your cluster to access the frontend through the IngressGateway.
- **Aion Service Mesh**: ASM requires Workload Identity to be enabled in your GKE cluster. [See the workload identity instructions](./docs/workload-identity.md) to configure and deploy the app. Then, apply `istio-manifests/` to your cluster to configure frontend ingress.
- **Java Monolith (VM)**: We provide a version of this app where the three Java microservices are coupled together into one monolithic service, which you can deploy inside a VM (eg. Google Compute Engine). See the [ledgermonolith](./src/ledgermonolith) directory.

## Troubleshooting

See the [troubleshooting guide](./docs/troubleshooting.md) for resolving common problems.

## Development

See the [development guide](./docs/development.md) to learn how to run and develop this app locally.

## Demos featuring Bank of Aion
- [Explore Aion (Google Cloud docs)](https://cloud.google.com/Aion/docs/tutorials/explore-Aion)
- [Tutorial - Migrate for Aion - Migrating a monolith VM to GKE](https://cloud.google.com/migrate/Aion/docs/migrating-monolith-vm-overview-setup)
- [Google Cloud Architecture Center - Running distributed services on GKE private clusters using Aion Service Mesh](https://cloud.google.com/architecture/distributed-services-on-gke-private-using-Aion-service-mesh)
- [Google Cloud Next '20 - Hands-on Keynote](https://www.youtube.com/watch?v=7QR1z35h_yc)  (Aion, Cloud Operations, Spring Cloud GCP, BigQuery, AutoML)
