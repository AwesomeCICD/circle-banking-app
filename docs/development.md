# Development Guide

This document describes how to develop and add features to the Bank of Anthos application in your local environment. 

## Prerequisites 

Access to SE team [CERA plaform](https://github.com/AwesomeCICD/reference-architecture). 

OR

Access to a forked / branched cluster.

**Skaffold will use whatever context is active for kubectl**

## Install Tools 

You can use MacOS or Linux as your dev environment - all these languages and tools support both. 

1. [Docker Desktop](https://www.docker.com/products/docker-desktop) 
1. [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) (can be installed separately or via [gcloud](https://cloud.google.com/sdk/install)) 
1. [skaffold **1.27+**](https://skaffold.dev/docs/install/) (latest version recommended)
1. [OpenJDK **17**](https://openjdk.java.net/projects/jdk/17/) (newer versions not tested)
1. [Python **3.7+**](https://www.python.org/downloads/)  
1. [piptools](https://pypi.org/project/pip-tools/)

### Installing JDK 17 and Maven 3.8

If your package manager doesn't allow you to install JDK 17 or Maven 3.8 (for example, if you're on an older version of Ubuntu), you can follow the following instructions.

Find the [latest release of JDK 17](https://jdk.java.net/17/) and extract it to the `/opt` directory:
```
wget https://download.java.net/java/GA/jdk17.0.1/2a2082e5a09d4267845be086888add4f/12/GPL/openjdk-17.0.1_linux-x64_bin.tar.gz
tar xvf openjdk-17.0.1_linux-x64_bin.tar.gz
sudo mv jdk-17*/ /opt/jdk17
```

**Maven 3.8** is included using the `maven wrapper` pattern.  All maven commands should use the `mvnw` executable in root of this project. 

i.e. `mvn test` becomes `./mvnw test`

This ensures all team members and CI builds get conistent results.

If you have multiple versions of Java/Python you can create a profile containing the paths of the newly extracted JDK and Maven directories:
```
sudo tee /etc/profile.d/java.sh <<EOF
export JAVA_HOME=/opt/jdk17
export M2_HOME=/opt/apache-maven-3.8.5
export MAVEN_HOME=/opt/apache-maven-3.8.5
export PATH=\$JAVA_HOME/bin:\$M2_HOME/bin:\$PATH
EOF
sudo chmod +x /etc/profile.d/java.sh
```

Verify that the versions are correct:
```
source /etc/profile.d/java.sh
java -version
mvn -version
```

## Adding External Packages 

### Python 

If you're adding a new feature that requires a new external Python package in one or more services (`frontend`, `contacts`, `userservice`), you must regenerate the `requirements.txt` file using `piptools`. This is what the Python Dockerfiles use to install external packages inside the containers.

NOTE: Pip-tools is a lighter/faster tool compared to pipenv, and [supported by pipenv maintainer](https://github.com/jazzband/pip-tools/issues/679#issuecomment-418951792). If we see need to switch we can.

To add a package: 

1. Add the package name to `requirements.in` within the `src/<service>` directory:

2. From inside that directory, run: 

```
python3 -m pip install pip-tools
python3 -m piptools compile --output-file=requirements.txt requirements.in
```

3. Re-run `skaffold dev` or `skaffold run` to trigger a Docker build using the updated `requirements.txt`.  


### Java 

If you're adding a new feature to one or more of the Java services (`ledgerwriter`, `transactionhistory`, `balancereader`) and require a new third-party package, do the following:  

1. Add the package to the `pom.xml` file in the `src/<service>` directory, under `<dependencies>`. You can find specific package info in [Maven Central](https://search.maven.org/) ([example](https://search.maven.org/artifact/org.postgresql/postgresql/42.2.16.jre7/jar)). Example: 

```
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
        </dependency>
```


2. Re-run `skaffold dev` or `skaffold run` to trigger a Jib container build using Maven and the updated pom file. 


## Generating your own JWT public key. 

The [extras](/extras/jwt) directory provides the RSA key/pair secret used for demos. To create your own: 

```
openssl genrsa -out jwtRS256.key 4096
openssl rsa -in jwtRS256.key -outform PEM -pubout -out jwtRS256.key.pub
kubectl create secret generic jwt-key --from-file=./jwtRS256.key --from-file=./jwtRS256.key.pub
```

## Testing your changes locally 
- [ ] TODO: CHANGES NEEDED TO APPLY TO AWS EKS ONCE NEXUS IS READY

We recommend you test and build directly on Kubernetes, from your local environment.  This is because there are seven services and for the app to fully function, all the services need to be running. All the services have dependencies, environment variables, and secrets and that are built into the Kubernetes environment / manifests, so testing directly on Kubernetes is the fastest way to see your code changes in action.

You can use the `skaffold` tool to build and deploy your code to the GKE cluster in your project. 

**NOTE:** You must set docker to login to ECR with

```shell
aws sso login #see SE WIki for guidance
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 483285841698.dkr.ecr.us-west-2.amazonaws.com 
```

### Option 1 - Build and deploy continuously 

The [`skaffold dev`](https://skaffold.dev/docs/references/cli/#skaffold-dev) command watches your local code, and continuously builds and deploys container images to your GKE cluster anytime you save a file. Skaffold uses Docker Desktop to build the Python images, then [Jib](https://github.com/GoogleContainerTools/jib#jib) (installed via Maven) to build the Java images. 

```
# kubectl config use-context <CLUSTER_CONTEXT_TO_TARGET>
skaffold dev --default-repo=483285841698.dkr.ecr.us-west-2.amazonaws.com -n MY_NAMESPACE
```


### Option 2 - Build and deploy once 

The [`skaffold run`](https://skaffold.dev/docs/references/cli/#skaffold-run) command build and deploys the services to your GKE cluster one time, then exits. 

```
skaffold run --default-repo=483285841698.dkr.ecr.us-west-2.amazonaws.com 
```

### Running services selectively

Skaffold reads the [skaffold.yaml](../skaffold.yaml) file to understand the project setup. Here, it's split into modules that can be iterated on individually:
- the `backend` module comprising of the five backend services.
- the `frontend` module for the single frontend service.
- the `loadbalancer` module for the single loadbalancer service. 

**The `setup` mofule must prefix many of the modules.  running `-m setup,...` should fix it.

To work with only the `frontend` module, run:

```
skaffold dev --default-repo=483285841698.dkr.ecr.us-west-2.amazonaws.com  -m setup,frontend
```

To work with both `frontend` and `backend` modules, run:

```
skaffold dev --default-repo=483285841698.dkr.ecr.us-west-2.amazonaws.com  -m setup -m frontend -m backend
```

## Continuous Integration

Checkout `.circleci/config.yml` for CI steps
