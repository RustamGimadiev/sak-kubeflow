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
  domains                           = ["swiss-army-grusakov.sak-grusakov.edu.provectus.io"]
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

module "external_secrets" {
  source       = "github.com/provectus/sak-external-secrets?ref=ench-use-template-for-module"
  argocd       = module.argocd.state
  cluster_name = module.kubernetes.cluster_name
}

module "external_dns" {
  source       = "github.com/provectus/sak-external-dns"
  cluster_name = module.kubernetes.cluster_name
  argocd       = module.argocd.state
  hostedzones  = ["swiss-army-grusakov.sak-grusakov.edu.provectus.io"]
}

### Hard way to install ALB ingress controller
module "application" {
  source = "git::https://github.com/provectus/sak-incubator//meta-aws-application?ref=49e8ec3def5585cb8decb5f4e6583669efb52bc0"

  chart_version = "1.2.7"
  repository    = "https://aws.github.io/eks-charts"
  name          = "aws-load-balancer-controller"
  chart         = "aws-load-balancer-controller"
  namespace     = "kube-system"

  iam_permissions = [
    {
      "Action" = [
        "iam:CreateServiceLinkedRole",
        "ec2:DescribeAccountAttributes",
        "ec2:DescribeAddresses",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeInternetGateways",
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeInstances",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeTags",
        "ec2:GetCoipPoolUsage",
        "ec2:DescribeCoipPools",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeLoadBalancerAttributes",
        "elasticloadbalancing:DescribeListeners",
        "elasticloadbalancing:DescribeListenerCertificates",
        "elasticloadbalancing:DescribeSSLPolicies",
        "elasticloadbalancing:DescribeRules",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetGroupAttributes",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:DescribeTags",
      ]
      "Effect"   = "Allow"
      "Resource" = "*"
    },
    {
      "Action" = [
        "cognito-idp:DescribeUserPoolClient",
        "acm:ListCertificates",
        "acm:DescribeCertificate",
        "iam:ListServerCertificates",
        "iam:GetServerCertificate",
        "waf-regional:GetWebACL",
        "waf-regional:GetWebACLForResource",
        "waf-regional:AssociateWebACL",
        "waf-regional:DisassociateWebACL",
        "wafv2:GetWebACL",
        "wafv2:GetWebACLForResource",
        "wafv2:AssociateWebACL",
        "wafv2:DisassociateWebACL",
        "shield:GetSubscriptionState",
        "shield:DescribeProtection",
        "shield:CreateProtection",
        "shield:DeleteProtection",
      ]
      "Effect"   = "Allow"
      "Resource" = "*"
    },
    {
      "Action" = [
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress",
      ]
      "Effect"   = "Allow"
      "Resource" = "*"
    },
    {
      "Action" = [
        "ec2:CreateSecurityGroup",
      ]
      "Effect"   = "Allow"
      "Resource" = "*"
    },
    {
      "Action" = [
        "ec2:CreateTags",
      ]
      "Condition" = {
        "Null" = {
          "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
        }
        "StringEquals" = {
          "ec2:CreateAction" = "CreateSecurityGroup"
        }
      }
      "Effect"   = "Allow"
      "Resource" = "arn:aws:ec2:*:*:security-group/*"
    },
    {
      "Action" = [
        "ec2:CreateTags",
        "ec2:DeleteTags",
      ]
      "Condition" = {
        "Null" = {
          "aws:RequestTag/elbv2.k8s.aws/cluster"  = "true"
          "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
        }
      }
      "Effect"   = "Allow"
      "Resource" = "arn:aws:ec2:*:*:security-group/*"
    },
    {
      "Action" = [
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:DeleteSecurityGroup",
      ]
      "Condition" = {
        "Null" = {
          "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
        }
      }
      "Effect"   = "Allow"
      "Resource" = "*"
    },
    {
      "Action" = [
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:CreateTargetGroup",
      ]
      "Condition" = {
        "Null" = {
          "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
        }
      }
      "Effect"   = "Allow"
      "Resource" = "*"
    },
    {
      "Action" = [
        "elasticloadbalancing:CreateListener",
        "elasticloadbalancing:DeleteListener",
        "elasticloadbalancing:CreateRule",
        "elasticloadbalancing:DeleteRule",
      ]
      "Effect"   = "Allow"
      "Resource" = "*"
    },
    {
      "Action" = [
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:RemoveTags",
      ]
      "Condition" = {
        "Null" = {
          "aws:RequestTag/elbv2.k8s.aws/cluster"  = "true"
          "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
        }
      }
      "Effect" = "Allow"
      "Resource" = [
        "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
        "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
        "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*",
      ]
    },
    {
      "Action" = [
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:RemoveTags",
      ]
      "Effect" = "Allow"
      "Resource" = [
        "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
        "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
        "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
        "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*",
      ]
    },
    {
      "Action" = [
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:SetIpAddressType",
        "elasticloadbalancing:SetSecurityGroups",
        "elasticloadbalancing:SetSubnets",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:ModifyTargetGroup",
        "elasticloadbalancing:ModifyTargetGroupAttributes",
        "elasticloadbalancing:DeleteTargetGroup",
      ]
      "Condition" = {
        "Null" = {
          "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
        }
      }
      "Effect"   = "Allow"
      "Resource" = "*"
    },
    {
      "Action" = [
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:DeregisterTargets",
      ]
      "Effect"   = "Allow"
      "Resource" = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
    },
    {
      "Action" = [
        "elasticloadbalancing:SetWebAcl",
        "elasticloadbalancing:ModifyListener",
        "elasticloadbalancing:AddListenerCertificates",
        "elasticloadbalancing:RemoveListenerCertificates",
        "elasticloadbalancing:ModifyRule"
      ]
      "Effect"   = "Allow"
      "Resource" = "*"
    }
  ]

  irsa_annotation_field = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
  cluster_name          = module.kubernetes.cluster_name
  values = {
    clusterName = module.kubernetes.cluster_name
    vpcId       = module.network.vpc_id
    region      = aws_s3_bucket.storage.region
  }
  argocd = module.argocd.state
}

resource "local_file" "alb_ingress_controller_crds" {
  filename = "${module.argocd.state.path}/aws-load-balancer-controller-crds.yaml"
  content = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "aws-load-balancer-controller-crds"
      namespace = module.argocd.state.namespace
    }
    spec = {
      destination = {
        namespace = "kube-system"
        server    = "https://kubernetes.default.svc"
      }
      source = {
        path           = "stable/aws-load-balancer-controller/crds/"
        repoURL        = "https://github.com/aws/eks-charts"
        targetRevision = "v0.0.63"
      }
    }
    }
  )
}

### Kubeflow specific resources
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
