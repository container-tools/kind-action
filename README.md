# Kubernetes KinD Cluster Action

[![](https://github.com/container-tools/kind-action/workflows/Test/badge.svg?branch=main)](https://github.com/container-tools/kind-action/actions)

A GitHub Action for starting a Kubernetes cluster with a local registry using [KinD](https://kind.sigs.k8s.io/).

This action provides an insecure registry on `kind-registry:5000` by default: it can be used to publish and deploy container images into KinD.

## Usage

### Pre-requisites

Create a workflow YAML file in your `.github/workflows` directory. An [example workflow](#example-workflow) is available below.
For more information, reference the GitHub Help Documentation for [Creating a workflow file](https://help.github.com/en/articles/configuring-a-workflow#creating-a-workflow-file).

### Inputs

For more information on inputs, see the [API Documentation](https://developer.github.com/v3/repos/releases/#input)

- `version`: The KinD version to use (default: `v0.9.0`)
- `config`: The path to the KinD config file
- `node_image`: The Docker image for the cluster nodes
- `cluster_name`: The name of the cluster to create (default: `kind`)
- `wait`: The duration to wait for the control plane to become ready (default: `60s`)
- `log_level`: The log level for KinD
- `registry`: Configures an insecure registry on `kind-registry:5000` to be used with KinD (default: `true`)

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

## Credits

This action leverages the good work done by the Helm community on [@helm/kind-action](https://www.github.com/helm/kind-action).
