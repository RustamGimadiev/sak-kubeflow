#
# Locals block to define a comment block to add at the top of each generated file
#
locals {
  kf_comment_block = [
    "# -----------------------------",
    "#",
    "# This file is generated during Terraform apply.",
    "# Please refer to module sak-kubeflow:",
    "#   ${var.argocd.repository}",
    "# to make changes to this file.",
    "#",
    "# -----------------------------"
  ]
}

resource "local_file" "kubeflow_root_application" {
  filename = "${path.root}/${var.argocd.path}/kubeflow.yaml"
  content = join("\n", concat(local.kf_comment_block, [yamlencode(
    {
      apiVersion = "argoproj.io/v1alpha1"
      kind       = "Application"
      metadata = {
        name      = "kubeflow-resources"
        namespace = var.argocd.namespace
      }
      spec = {
        destination = {
          namespace = "kubeflow"
          server    = "https://kubernetes.default.svc"
        }
        project = var.argocd.project
        source = {
          directory = {
            recurse = true
          }
          path           = "${var.argocd.full_path}/kubeflow"
          repoURL        = var.argocd.repository
          targetRevision = var.argocd.branch
        }
        syncPolicy = {
          syncOptions = ["CreateNamespace=true"]
          automated = {
            prune    = "true"
            selfHeal = "true"
          }
        }
      }
    }
    )
  ])) # close the join( concat( [ ] ) ) wrapper
}

resource "local_file" "kubeflow_argo_application" {
  filename = "${path.root}/${var.argocd.path}/kubeflow/kubeflow.yaml"
  content = join("\n", concat(local.kf_comment_block, [yamlencode(
    {
      apiVersion = "argoproj.io/v1alpha1"
      kind       = "Application"
      metadata = {
        name      = "kubeflow"
        namespace = "argo-cd"
      }
      spec = {
        ignoreDifferences = [
          {
            group = "rbac.authorization.k8s.io"
            kind  = "ClusterRole"
            jsonPointers = [
              "/rules"
            ]
          },
          {
            group = "admissionregistration.k8s.io"
            kind  = "MutatingWebhookConfiguration"
            jsonPointers = [
              "/webhooks/0/clientConfig/caBundle"
            ]
          }
        ]
        destination = {
          namespace = "kubeflow"
          server    = "https://kubernetes.default.svc"
        }
        project = "default"
        source = {
          path           = "base/kubeflow"
          repoURL        = var.argocd.repository
          targetRevision = var.argocd.branch
          kustomize = {
            version = "v3.2.0"
          }
        }
        syncPolicy = {
          syncOptions = ["CreateNamespace=true"]
          automated = {
            prune    = "true"
            selfHeal = "true"
          }
        }
      }
    }
    )
  ])) # close the join( concat( [ ] ) ) wrapper
}

resource "local_file" "istio_application" {
  filename = "${path.root}/${var.argocd.path}/kubeflow/istio.yaml"
  content = join("\n", concat(local.kf_comment_block, [yamlencode(
    {
      apiVersion = "argoproj.io/v1alpha1"
      kind       = "Application"
      metadata = {
        name      = "istio"
        namespace = "argo-cd"
      }
      spec = {
        ignoreDifferences = [
          {
            group = "admissionregistration.k8s.io"
            kind  = "MutatingWebhookConfiguration"
            jsonPointers = [
              "/webhooks/0/clientConfig/caBundle"
            ]
          },
          {
            group = "admissionregistration.k8s.io"
            kind  = "ValidatingWebhookConfiguration"
            jsonPointers = [
              "/webhooks/0/clientConfig/caBundle",
              "/webhooks/0/failurePolicy"
            ]
          }
        ]
        destination = {
          namespace = "istio-system"
          server    = "https://kubernetes.default.svc"
        }
        project = "default"
        source = {
          path           = "base/istio"
          repoURL        = var.argocd.repository
          targetRevision = var.argocd.branch
          kustomize = {
            version = "v3.2.0"
          }
        }
        syncPolicy = {
          syncOptions = ["CreateNamespace=true"]
          automated = {
            prune    = "true"
            selfHeal = "true"
          }
        }
      }
    }
    )
  ])) # close the join( concat( [ ] ) ) wrapper
}

resource "local_file" "kubeflow_cm" {
  filename = "${path.root}/${var.argocd.path}/kubeflow/cloud-workflow-controller-configmap.yaml"
  content = join("\n", concat(local.kf_comment_block, [yamlencode(
    {
      apiVersion = "v1"
      kind       = "ConfigMap"
      metadata = {
        name      = "cloud-workflow-controller-configmap"
        namespace = "kubeflow"
      }
      data = {
        namespace                = ""
        executorImage            = "gcr.io/ml-pipeline/argoexec:v3.1.6-patch-license-compliance"
        containerRuntimeExecutor = "docker"
        artifactRepository = yamlencode({
          archiveLogs = true
          s3 = {
            bucket    = var.kf_bucket_id
            keyPrefix = "artifacts"
            endpoint  = "minio-service.kubeflow:9000"
            insecure  = true
            accessKeySecret = {
              name = "cloud-mlpipeline-minio-artifact"
              key  = "accesskey"
            }
            secretKeySecret = {
              name = "cloud-mlpipeline-minio-artifact"
              key  = "secretkey"
            }
          }
        })
      }
    }
    )
  ])) # close the join( concat( [ ] ) ) wrapper
}

resource "aws_secretsmanager_secret" "kubeflow" {
  name = "/eks/${var.cluster_name}/${var.environment}-kubeflow"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "kubeflow" {
  secret_id = aws_secretsmanager_secret.kubeflow.id
  secret_string = jsonencode({
    cloud-db-username       = var.kf_db_master_username
    cloud-db-password       = var.kf_db_master_password
    cloud-access-key-id     = var.kf_user_credentials_id
    cloud-secret-access-key = var.kf_user_credentials_secret
    static-user-password    = var.default_user_password
    oidc_provider           = "https://kubeflow.${var.external_dns_domain}/dex"
  })
}

resource "local_file" "secrets" {
  filename = "${path.root}/${var.argocd.path}/kubeflow/cloud-secrets.yaml"
  content = join("\n", concat(local.kf_comment_block, [yamlencode(
    {
      apiVersion = "kubernetes-client.io/v1"
      kind       = "ExternalSecret"
      metadata = {
        name      = "kubeflow-cloud-secrets"
        namespace = "kubeflow"
      }
      spec = {
        backendType = "secretsManager"
        data = [
          {
            key      = aws_secretsmanager_secret.kubeflow.name
            name     = "cloud-db-username"
            property = "cloud-db-username"
          },
          {
            key      = aws_secretsmanager_secret.kubeflow.name
            name     = "cloud-db-password"
            property = "cloud-db-password"
          }
        ]
      }
    }
    )
  ])) # close the join( concat( [ ] ) ) wrapper
}

resource "local_file" "istio_secrets" {
  filename = "${path.root}/${var.argocd.path}/kubeflow/authservice-sso-secrets.yaml"
  content = join("\n", concat(local.kf_comment_block, [yamlencode(
    {
      apiVersion = "kubernetes-client.io/v1"
      kind       = "ExternalSecret"
      metadata = {
        name      = "authservice-sso-secret"
        namespace = "istio-system"
      }
      spec = {
        backendType = "secretsManager"
        data = [
          {
            key      = aws_secretsmanager_secret.kubeflow.name
            name     = "OIDC_PROVIDER"
            property = "oidc_provider"
          }
        ]
      }
    }
    )
  ])) # close the join( concat( [ ] ) ) wrapper
}

resource "local_file" "sso_secrets" {
  filename = "${path.root}/${var.argocd.path}/kubeflow/dex-sso-secrets.yaml"
  content = join("\n", concat(local.kf_comment_block, [yamlencode(
    {
      apiVersion = "kubernetes-client.io/v1"
      kind       = "ExternalSecret"
      metadata = {
        name      = "dex-sso-secret"
        namespace = "auth"
      }
      spec = {
        backendType = "secretsManager"
        data = [
          {
            key      = "/eks/${var.cluster_name}/kubeflow-github-sso-secret"
            name     = "DEX_GITHUB_CLIENT_ID"
            property = "CLIENT_ID"
          },
          {
            key      = "/eks/${var.cluster_name}/kubeflow-github-sso-secret"
            name     = "DEX_GITHUB_CLIENT_SECRET"
            property = "CLIENT_SECRET"
          },
          {
            key      = aws_secretsmanager_secret.kubeflow.name
            name     = "DEX_STATIC_USER_PASSWORD"
            property = "static-user-password"
          }
        ]
      }
    }
    )
  ])) # close the join( concat( [ ] ) ) wrapper
}

resource "local_file" "ingress" {
  filename = "${path.root}/${var.argocd.path}/kubeflow/kubeflow-ingress.yaml"
  content = join("\n", concat(local.kf_comment_block, [yamlencode(
    {
      apiVersion = "networking.k8s.io/v1"
      kind       = "Ingress"
      metadata = {
        name      = "kubeflow"
        namespace = "istio-system"
        labels = {
          name = "kubeflow"
        }
        annotations = {
          "alb.ingress.kubernetes.io/certificate-arn" = var.certificate_arn
          "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
          "alb.ingress.kubernetes.io/group.name"      = "kubeflow"
          "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
          "alb.ingress.kubernetes.io/target-type"     = "ip"
          "kubernetes.io/ingress.class"               = "alb"
        }
      }
      spec = {
        rules = [
          {
            host = "kubeflow.${var.external_dns_domain}"
            http = {
              paths = [
                {
                  pathType = "Prefix"
                  path     = "/"
                  backend = {
                    service = {
                      name = "istio-ingressgateway"
                      port = {
                        number = 80
                      }
                    }
                  }
                }
              ]
            }
          }
        ]
      }
    }
    )
  ])) # close the join( concat( [ ] ) ) wrapper
}

resource "local_file" "config" {
  filename = "${path.root}/${var.argocd.path}/kubeflow/cloud-configmap.yaml"
  content = join("\n", concat(local.kf_comment_block, [yamlencode(
    {
      apiVersion = "v1"
      kind       = "ConfigMap"
      metadata = {
        name      = "kubeflow-cloud-config"
        namespace = "kubeflow"
      }
      data = {
        cloud-db-address          = var.kf_db_endpoint
        cloud-storage-bucket-name = var.kf_bucket_id
        cloud-storage-endpoint    = "storage.${var.kf_bucket_region}.amazonaws.com"
        cloud-region              = var.kf_bucket_region
      }
    }
    )
  ])) # close the join( concat( [ ] ) ) wrapper
}


resource "local_file" "mlpipeline_minio_artifact" {
  filename = "${path.root}/${var.argocd.path}/kubeflow/cloud-mlpipeline-minio-artifact.yaml"
  content = join("\n", concat(local.kf_comment_block, [yamlencode(
    {
      apiVersion = "kubernetes-client.io/v1"
      kind       = "ExternalSecret"
      metadata = {
        name      = "cloud-mlpipeline-minio-artifact"
        namespace = "kubeflow"
      }
      spec = {
        backendType = "secretsManager"
        data = [
          {
            key      = aws_secretsmanager_secret.kubeflow.name
            name     = "accesskey"
            property = "cloud-access-key-id"
          },
          {
            key      = aws_secretsmanager_secret.kubeflow.name
            name     = "secretkey"
            property = "cloud-secret-access-key"
          }
        ]
      }
    }
    )
  ])) # close the join( concat( [ ] ) ) wrapper
}

resource "aws_iam_user_policy" "this" {
  name = var.cluster_name
  user = var.iam_user_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetBucket*",
          "s3:List*",
          "s3:Describe*"
        ]
        Effect   = "Allow"
        Resource = ["*"]
      },
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Effect   = "Allow"
        Resource = [var.kf_bucket_arn, "${var.kf_bucket_arn}/*"]
      },
    ]
  })
}

resource "local_file" "dex_config" {
  filename = "${path.root}/${var.argocd.path}/kubeflow/dex-configmap.yaml"
  content = join("\n", concat(local.kf_comment_block, [yamlencode(
    {
      apiVersion = "v1"
      kind       = "ConfigMap"
      metadata = {
        name      = "dex-config"
        namespace = "auth"
      }
      data = {
        "config.yaml" = yamlencode(
          {
            "connectors" = [
              {
                "config" = {
                  "clientID"     = "$${DEX_GITHUB_CLIENT_ID}"
                  "clientSecret" = "$${DEX_GITHUB_CLIENT_SECRET}"
                  "orgs" = [
                    {
                      "name"  = "pepsico-ecommerce"
                      "teams" = var.github_teams_with_access_to_kubeflow
                    },
                  ]
                  "redirectURI" = "https://kubeflow.${var.external_dns_domain}/dex/callback"
                }
                "id"   = "github"
                "name" = "GitHub"
                "type" = "github"
              },
            ]
            "enablePasswordDB" = true
            "issuer"           = "https://kubeflow.${var.external_dns_domain}/dex"
            "logger" = {
              "format" = "text"
              "level"  = "debug"
            }
            "oauth2" = {
              "skipApprovalScreen" = true
            }
            "staticClients" = [
              {
                "idEnv" = "OIDC_CLIENT_ID"
                "name"  = "Dex Login Application"
                "redirectURIs" = [
                  "/login/oidc",
                ]
                "secretEnv" = "OIDC_CLIENT_SECRET"
              },
            ]
            "staticPasswords" = [
              {
                "email"       = "user@example.com"
                "hashFromEnv" = "DEX_STATIC_USER_PASSWORD"
                "userID"      = "15841185641784"
                "username"    = "user"
              },
            ]
            "storage" = {
              "config" = {
                "inCluster" = true
              }
              "type" = "kubernetes"
            }
            "web" = {
              "http" = "0.0.0.0:5556"
            }
          }
        )
      }
    }
    )
  ])) # close the join( concat( [ ] ) ) wrapper
}


resource "local_file" "kubeflow_profile" {
  for_each = {
    for u in var.kubeflow_users :
    u.name => u
  }
  content = join("\n", concat(local.kf_comment_block, [yamlencode(
    {
      "apiVersion" = "kubeflow.org/v1beta1"
      "kind"       = "Profile"
      "metadata" = {
        "annotations" = {
          "argocd.argoproj.io/sync-wave" = "5"
        }
        "name" = lower(replace(each.value.name, " ", "-"))
      }
      "spec" = {
        "owner" = {
          "kind" = "User"
          "name" = each.value.email
        }
        "plugins" = [
          {
            "kind" = "AwsIamForServiceAccount"
            "spec" = {
              "awsIamRole" = each.value.role_arn
            }
          },
        ]
        "resourceQuotaSpec" = {
          "hard" = {
            "requests.storage" = "1Gi"
          }
        }

      }
    }
    )
  ])) # close the join( concat( [ ] ) ) wrapper
  file_permission      = "0644"
  directory_permission = "0755"
  filename             = "${path.root}/${var.argocd.path}/kubeflow/profiles/${lower(replace(each.value.name, " ", "-"))}.yaml"
}
