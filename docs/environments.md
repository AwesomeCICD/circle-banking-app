# Running in Kubernetes Environments

## EKS

The CircleCI @SolutionsEngineering team maintains this repo for deployment to AWS EKS.  

### Cluster Namespaces and Service Accounts

Each CERA Cluster (one per region, and also feature branches) has Service Accounts automaticallycreated for Bank Corp App.

The Service Accounts allow App application to talk to EKS cluster without AWS admin credentials.

See `reference-architecture` repo for provisioning.