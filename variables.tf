variable "cluster_name" {
  type        = string
  description = "A name of the AWS EKS cluster"
}

variable "argocd" {
  type        = any
  description = "A ArgoCD module state from SAK deployment"
}

variable "external_dns_domain" {
  type        = string
  description = "A Route53 domain"
}

variable "environment" {
  type        = string
  description = "The environment name"
}

variable "kf_bucket_id" {
  type        = string
  description = "A S3 bucket name for Kubeflow artifacts"
}

variable "kf_bucket_arn" {
  type        = string
  description = "A S3 bucket ARN for Kubeflow artifacts"
}

variable "kf_bucket_region" {
  type        = string
  description = "A S3 bucket region for Kubeflow artifacts"
}

variable "iam_user_name" {
  type        = string
  description = "A name of the IAM user for Kubeflow access to AWS resources"
}

variable "kf_user_credentials_id" {
  type        = string
  description = "A Access ID of programmatic credentials for the IAM user"
}

variable "kf_user_credentials_secret" {
  type        = string
  description = "A Secret Access Key of programmatic credentials for the IAM user"
}

variable "kf_db_master_username" {
  type        = string
  description = "A database username for Kubeflow services"
}

variable "kf_db_endpoint" {
  type        = string
  description = "A database host for Kubeflow services"
}

variable "kf_db_master_password" {
  type        = string
  description = "A database password for Kubeflow services"
}

variable "certificate_arn" {
  type        = string
  description = "An arn of the ACM certificate that will be used in ALB"
}

variable "default_user_password" {
  type        = string
  description = "A password for default Kubeflow user, bcrypt string"
  default     = "$2y$12$4K/VkmDd1q1Orb3xAt82zu8gk7Ad6ReFR4LCP9UeYE90NLiN9Df72"
}

variable "kubeflow_users" {
  type        = any
  description = "Add role arn for profile. Variable example: [{name = \"Billy\", email = \"billy@yahoo.com\", arn = \"Herrington\", teams = [\"DSA\"] }]"
}

variable "tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the resource"
  default     = {}
}

variable "github_teams_with_access_to_kubeflow" {
  type    = list(string)
  default = []
}
