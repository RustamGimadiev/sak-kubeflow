# Base Kustomization folder

This folder contains Kustomization manifests for Istio and Kubeflow deployment independently for environments, all of them reused for all possible deployments.

## Istio
Basic Istio setup from the Kustomization manifests located in [kubeflow/manifests](https://github.com/kubeflow/manifests) repository, installed as-is without changes.

## Kubeflow
Deployment instructions for installing base Kubeflow cloud-agnostic version with additional AWS patches, to read more follow to [it own documentation](kubeflow/README.md)
