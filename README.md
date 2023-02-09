# Kubernetes KinD Cluster Action

[![](https://github.com/container-tools/kind-action/workflows/Test/badge.svg?branch=main)](https://github.com/container-tools/kind-action/actions)

A GitHub Action for starting a Kubernetes cluster with a local registry and optional addons (Knative) using [KinD](https://kind.sigs.k8s.io/).

This action provides an insecure registry on `kind-registry:5000` by default: it can be used to publish and deploy container images into KinD.

## Usage

### Pre-requisites

Create a workflow YAML file in your `.github/workflows` directory. An [example workflow](#example-workflow) is available below.
For more information, reference the GitHub Help Documentation for [Creating a workflow file](https://help.github.com/en/articles/configuring-a-workflow#creating-a-workflow-file).

### Inputs

For more information on inputs, see the [API Documentation](https://developer.github.com/v3/repos/releases/#input)

- `version`: The KinD version to use (default: `v0.17.0`)
- `config`: The path to the KinD config file
- `node_image`: The Docker image for the cluster nodes
- `cluster_name`: The name of the cluster to create (default: `kind`)
- `wait`: The duration to wait for the control plane to become ready (default: `60s`)
- `log_level`: The log level for KinD
- `registry`: Configures an insecure registry on `kind-registry:5000` to be used with KinD (default: `true`)
- `kubectl_version`: The kubectl version to use (default: `v1.26.1`)
- `knative_serving`: The version of Knative Serving to install on the Kind cluster (not installed by default - example: `v1.0.0`)
- `knative_kourier`: The version of Knative Net Kourier to install on the Kind cluster (not installed by default - example: `v1.0.0`)
- `knative_eventing`: The version of Knative Eventing to install on the Kind cluster (not installed by default - example: `v1.0.0`)
- `cpu`: Number of CPUs to be allocated to the virtual machine (default: 2). For Mac OS only.
- `memory`: Size of the memory in GiB to be allocated to the virtual machine (default: 12). For Mac OS only.
- `disk`: Size of the disk in GiB to be allocated to the virtual machine (default: 60). For Mac OS only.

### Example Workflow

Create a workflow (eg: `.github/workflows/create-cluster.yml`):

```yaml
name: Create Cluster

on: pull_request

jobs:
  create-cluster:
    runs-on: ubuntu-latest
    steps:
      - name: Kubernetes KinD Cluster
        uses: container-tools/kind-action@v1
```

This uses [@container-tools/kind-action](https://www.github.com/container-tools/kind-action) GitHub Action to spin up a [KinD](https://kind.sigs.k8s.io/) Kubernetes cluster on every Pull Request.

A container registry will be created with address `kind-registry:5000` on both the host and the cluster.
The registry address is stored in the `KIND_REGISTRY` environment variable, also for the subsequent steps.

### Configuring Addons

Create a workflow (eg: `.github/workflows/create-cluster-with-addons.yml`):

```yaml
name: Create Cluster with Addons

on: pull_request

jobs:
  create-cluster-with-addons:
    runs-on: ubuntu-latest
    steps:
      - name: Kubernetes KinD Cluster
        uses: container-tools/kind-action@v1
        with:
          knative_serving: v1.0.0
          knative_kourier: v1.0.0
          knative_eventing: v1.0.0
```

This will install Knative Serving, Eventing and a Kourier Ingress on your Kind cluster. To make Knative run on Kind, resource request and limits are removed from the original Knative descriptors.

## Credits

This action leverages the good work done by the Helm community on [@helm/kind-action](https://www.github.com/helm/kind-action).
