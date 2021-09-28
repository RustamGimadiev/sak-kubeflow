data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = data.aws_eks_cluster.cluster.name
}

locals {
  repository       = "https://github.com/kubeflow/manifests"
  kubeflow_release = "v1.4.0-rc.1"
  kfctl_release = "v1.2.0"
}

resource "local_file" "kubeflow_operator" {
  content = yamlencode({
    "apiVersion" = "argoproj.io/v1alpha1"
    "kind"       = "Application"
    "metadata" = {
      "name"      = "kubeflow-operator"
      "namespace" = var.argocd.namespace
    }
    "spec" = {
      "destination" = {
        "namespace" = "operators"
        "server"    = "https://kubernetes.default.svc"
      }
      "project" = var.argocd.project
      "source" = {
        "repoURL"        = "https://github.com/kubeflow/kfctl"
        "targetRevision" = "${local.kfctl_release}"
        "path"           = "deploy"
      }
      "syncPolicy" = {
        "syncOptions" = [
          "CreateNamespace=true"
        ]
        "automated" = {
          "prune"    = true
          "selfHeal" = true
        }
      }
    }
  })
  filename = "${path.root}/${var.argocd.path}/kubeflow-operator.yaml"
}

resource "local_file" "kubeflow" {
  count = var.create_kubeflow ? 1 : 0
  content = yamlencode({
    "apiVersion" = "argoproj.io/v1alpha1"
    "kind"       = "Application"
    "metadata" = {
      "name"      = "kubeflow"
      "namespace" = var.argocd.namespace
    }
    "spec" = {
      "destination" = {
        "namespace" = "kubeflow"
        "server"    = "https://kubernetes.default.svc"
      }
      "project" = var.argocd.project
      "source" = {
        "repoURL"        = var.argocd.repository
        "targetRevision" = var.argocd.branch
        "path"           = "${var.argocd.full_path}/kubeflow"
        "plugin" = {
          "name" = "decryptor"
        }
      }
      "syncPolicy" = {
        "syncOptions" = [
          "CreateNamespace=true"
        ]
        "automated" = {
          "prune"    = true
          "selfHeal" = true
        }
      }
    }
  })
  filename = "${path.root}/${var.argocd.path}/kubeflow.yaml"
}

resource "local_file" "kubeflow" {
  count = var.create_kubeflow ? 1 : 0
  content = yamlencode({
    "apiVersion" = "argoproj.io/v1alpha1"
    "kind"       = "Application"
    "metadata" = {
      "name"      = "kubeflow"
      "namespace" = var.argocd.namespace
    }
    "spec" = {
      "destination" = {
        "namespace" = "kubeflow"
        "server"    = "https://kubernetes.default.svc"
      }
      "project" = var.argocd.project
      "source" = {
        "repoURL"        = var.argocd.repository
        "targetRevision" = var.argocd.branch
        "path"           = "${var.argocd.full_path}/kubeflow"
        "plugin" = {
          "name" = "decryptor"
        }
      }
      "syncPolicy" = {
        "syncOptions" = [
          "CreateNamespace=true"
        ]
        "automated" = {
          "prune"    = true
          "selfHeal" = true
        }
      }
    }
  })
  filename = "${path.root}/${var.argocd.path}/kubeflow.yaml"
}

resource "aws_db_subnet_group" "default" {
  name_prefix = "${var.cluster_name}-"
  subnet_ids  = var.rds_subnets
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "aws_security_group" "rds" {
  name_prefix = "rds-${var.cluster_name}-"
  description = "Access to RDS"
  vpc_id      = var.rds_vpc_id

  ingress {
    description = "MySQL from EKS nodes"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = local.whitelisted
  }
}

resource "aws_db_instance" "default" {
  engine                 = "mysql"
  engine_version         = "5.7.31"
  instance_class         = "db.t3.micro"
  name                   = replace(var.cluster_name, "-", "")
  username               = "root"
  password               = random_password.password.result
  vpc_security_group_ids = [aws_security_group.rds.id, module.eks.worker_security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.default.name
  publicly_accessible    = true
  allocated_storage      = 20
  skip_final_snapshot    = true
}

resource "aws_kms_ciphertext" "pass" {
  key_id    = module.argocd.state.kms_key_id
  plaintext = base64encode(aws_db_instance.default.password)
}

resource "aws_kms_ciphertext" "secret" {
  key_id    = module.argocd.state.kms_key_id
  plaintext = base64encode(aws_iam_access_key.kfp.secret)
}

resource "aws_kms_ciphertext" "token" {
  key_id    = module.argocd.state.kms_key_id
  plaintext = local.vcs_token
}

resource "local_file" "rds_creds" {
  filename = "${module.argocd.state.path}/kubeflow/aws-rds-secrets.yaml"
  content = yamlencode(
    {
      apiVersion = "v1"
      kind       = "Secret"
      metadata = {
        name      = "aws-rds-secrets"
        namespace = "kubeflow"
      }
      type = "Opaque"
      data = {
        aws-rds-username = base64encode(aws_db_instance.default.username)
        aws-rds-password = "KMS_ENC:${aws_kms_ciphertext.pass.ciphertext_blob}:"
      }
    }
  )
}

resource "aws_iam_access_key" "kfp" {
  user = aws_iam_user.kfp.name
}

resource "aws_iam_user" "kfp" {
  name = "${var.cluster_name}-kfp"
}

resource "aws_iam_user_policy" "kfp" {
  name = "s3-access"
  user = aws_iam_user.kfp.name

  policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Action = [
            "s3:*"
          ],
          Effect   = "Allow",
          Resource = ["${aws_s3_bucket.storage.arn}/*", aws_s3_bucket.storage.arn]
        }
      ]
    }
  )
}

resource "aws_iam_policy" "s3_access" {
  description = "GetObject access to artifacts for Argo Workflow and KFP UI based on Instance Profile"
  name        = "${var.cluster_name}-kfp"
  policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Action = [
            "s3:GetObject"
          ],
          Effect   = "Allow",
          Resource = "${aws_s3_bucket.storage.arn}/*"
        }
      ]
    }
  )
}

resource "local_file" "s3_creds" {
  filename = "${module.argocd.state.path}/kubeflow/aws-s3-secrets.yaml"
  content = yamlencode(
    {
      apiVersion = "v1"
      kind       = "Secret"
      metadata = {
        name      = "aws-s3-secrets"
        namespace = "kubeflow"
      }
      type = "Opaque"
      data = {
        aws-access-key-id     = base64encode(aws_iam_access_key.kfp.id)
        aws-secret-access-key = "KMS_ENC:${aws_kms_ciphertext.secret.ciphertext_blob}:"
      }
    }
  )
}

resource "aws_s3_bucket" "storage" {
  bucket_prefix = "${local.}-${var.cluster_name}-"
  acl           = "private"
  force_destroy = true
}

resource "local_file" "aws_env" {
  filename = "${module.argocd.state.path}/../../manifests/aws/aws.env"
  content  = <<EOF
aws-s3-bucket-name=${aws_s3_bucket.storage.id}
aws-region=${var.aws_region}
aws-s3-endpoint=s3.amazonaws.com
aws-rds-address=${aws_db_instance.default.address}
  EOF
}

resource "local_file" "kubeflow" {
  filename = "${module.argocd.state.path}/kubeflow/kubeflow.yaml"
  content = yamlencode(
    {
      "apiVersion" = "kfdef.apps.kubeflow.org/v1"
      "kind"       = "KfDef"
      "metadata" = {
        "name"      = "kubeflow"
        "namespace" = "kubeflow"
      }
      "spec" = {
        "applications" = [
          {
            "kustomizeConfig" = {
              "repoRef" = {
                "name" = "manifests"
                "path" = "namespaces/base"
              }
            }
            "name" = "namespaces"
          },
          {
            "kustomizeConfig" = {
              "repoRef" = {
                "name" = "manifests"
                "path" = "application/v3"
              }
            }
            "name" = "application"
          },
          {
            "kustomizeConfig" = {
              "repoRef" = {
                "name" = "manifests"
                "path" = "stacks/aws/application/istio-1-3-1-stack"
              }
            }
            "name" = "istio-stack"
          },
          {
            "kustomizeConfig" = {
              "repoRef" = {
                "name" = "manifests"
                "path" = "stacks/aws/application/cluster-local-gateway-1-3-1"
              }
            }
            "name" = "cluster-local-gateway"
          },
          {
            "kustomizeConfig" = {
              "repoRef" = {
                "name" = "manifests"
                "path" = "istio/istio/base"
              }
            }
            "name" = "istio"
          },
          {
            "kustomizeConfig" = {
              "repoRef" = {
                "name" = "manifests"
                "path" = "stacks/aws/application/cert-manager-crds"
              }
            }
            "name" = "cert-manager-crds"
          },
          {
            "kustomizeConfig" = {
              "repoRef" = {
                "name" = "manifests"
                "path" = "stacks/aws/application/cert-manager-kube-system-resources"
              }
            }
            "name" = "cert-manager-kube-system-resources"
          },
          {
            "kustomizeConfig" = {
              "repoRef" = {
                "name" = "manifests"
                "path" = "stacks/aws/application/cert-manager"
              }
            }
            "name" = "cert-manager"
          },
          {
            "kustomizeConfig" = {
              "repoRef" = {
                "name" = "manifests"
                "path" = "metacontroller/base"
              }
            }
            "name" = "metacontroller"
          },
          {
            "kustomizeConfig" = {
              "repoRef" = {
                "name" = "manifests"
                "path" = "admission-webhook/bootstrap/overlays/application"
              }
            }
            "name" = "bootstrap"
          },
          {
            "kustomizeConfig" = {
              "repoRef" = {
                "name" = "state-repo"
                "path" = "manifests/aws"
              }
            }
            "name" = "kubeflow-apps"
          },
          {
            "kustomizeConfig" = {
              "repoRef" = {
                "name" = "manifests"
                "path" = "aws/istio-ingress/base_v3"
              }
            }
            "name" = "istio-ingress"
          },
          {
            "kustomizeConfig" = {
              "repoRef" = {
                "name" = "manifests"
                "path" = "stacks/kubernetes/application/add-anonymous-user-filter"
              }
            }
            "name" = "add-anonymous-user-filter"
          },
        ]
        "repos" = [
          {
            "name" = "state-repo"
            "uri"  = "https://KMS_ENC:${aws_kms_ciphertext.token.ciphertext_blob}:@${replace(local.vcs, "https://", "")}/${local.owner}/${local.repository}/archive/${local.branch}.tar.gz"
          },
          {
            "name" = "manifests"
            "uri"  = "https://github.com/kubeflow/manifests/archive/${local.kubeflow_release}.tar.gz"
          },
        ]
        "version" = local.kubeflow_release
      }
    }
  )
}
