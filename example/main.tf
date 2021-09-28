data "aws_eks_cluster" "cluster" {
  name = module.kubernetes.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.kubernetes.cluster_name
}

module "network" {
  source             = "github.com/provectus/sak-vpc"
  availability_zones = ["eu-north-1a", "eu-north-1b"]
  environment        = "development"
  project            = "sak"
  cluster_name       = "kubeflow"
}

module "kubernetes" {
  source                            = "github.com/provectus/sak-kubernetes"
  availability_zones                = ["eu-north-1a", "eu-north-1b"]
  environment                       = "development"
  project                           = "sak"
  cluster_name                      = "kubeflow"
  domains                           = [""]
  cluster_version                   = "1.21"
  vpc_id                            = module.network.vpc_id
  subnets                           = module.network.private_subnets
  on_demand_common_max_cluster_size = 1
  on_demand_cpu_max_cluster_size    = 0
}

module "argocd" {
  source        = "github.com/provectus/sak-argocd"
  branch        = "development"
  owner         = "RustamGimadiev"
  repository    = "sak-kubeflow"
  cluster_name  = module.kubernetes.cluster_name
  chart_version = "3.21.1"
  path_prefix   = "example/"
}

module "kubeflow" {
  source       = "../"
  argocd       = module.argocd.state
  cluster_name = module.kubernetes.cluster_name
}
