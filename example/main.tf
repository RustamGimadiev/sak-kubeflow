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
  domains                           = ["swiss-army-grusakov.sak-grusakov.edu.provectus.io "]
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

  certificate_arn            = aws_acm_certificate.kubeflow.arn
  default_user_password      = "PartyParrot"
  environment                = "development"
  external_dns_domain        = aws_acm_certificate.kubeflow.domain_name
  iam_user_name              = aws_iam_user.kubeflow.name
  kf_bucket_arn              = aws_s3_bucket.storage.arn
  kf_bucket_id               = aws_s3_bucket.storage.id
  kf_bucket_region           = aws_s3_bucket.storage.region
  kf_db_endpoint             = aws_db_instance.database.endpoint
  kf_db_master_password      = aws_db_instance.database.password
  kf_db_master_username      = aws_db_instance.database.username
  kf_user_credentials_id     = aws_iam_access_key.kubeflow.id
  kf_user_credentials_secret = aws_iam_access_key.kubeflow.secret
  kubeflow_users             = []
}

resource "aws_acm_certificate" "kubeflow" {
  domain_name       = "swiss-army-grusakov.sak-grusakov.edu.provectus.io"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_s3_bucket" "storage" {
  bucket = "${module.kubernetes.cluster_name}-kubeflow"
  acl    = "private"
}

resource "aws_db_subnet_group" "database" {
  subnet_ids = module.network.private_subnets
}

resource "aws_db_instance" "database" {
  allocated_storage    = 10
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  name                 = module.kubernetes.cluster_name
  username             = "admin"
  password             = "PartyParrot"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true

  db_subnet_group_name = aws_db_subnet_group.database.name
}

resource "aws_iam_user" "kubeflow" {
  name = module.kubernetes.cluster_name
}

resource "aws_iam_access_key" "kubeflow" {
  user = aws_iam_user.kubeflow.name
}
