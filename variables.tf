variable "cluster_name" {
  type        = string
  description = "A name of the AWS EKS cluster"
}

variable "argocd" {
  type = any
  description = "A ArgoCD module state from SAK deployment"
}

variable "create_kubeflow" {
  type = bool
  default = true
  description = "Create or not a Kubeflow deployment, if false only Kubeflow Operator will be installed"
}