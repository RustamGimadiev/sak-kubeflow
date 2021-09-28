provider "aws" {
  region = "eu-north-1"
  default_tags {
    tags = {
      ENV   = "development"
      PRJ   = "SAK"
      OWNER = "rgimadiev"
    }
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    exec {
      api_version = "client.authentication.k8s.io/v1alpha1"
      args        = ["eks", "get-token", "--cluster-name", module.kubernetes.cluster_name]
      command     = "aws"
    }
  }
}

terraform {
  required_version = ">=  1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.58.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.3.0"
    }
  }
}
