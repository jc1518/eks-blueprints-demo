# EKS Blueprints demo (one file for simplicity)

################################################################################
# Providers
################################################################################

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14"
    }
  }
}

provider "aws" {
  region = local.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubectl" {
  apply_retry_count      = 10
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false
  token                  = data.aws_eks_cluster_auth.this.token
}

################################################################################
# Data Sources
################################################################################

data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

################################################################################
# Local Values
################################################################################

locals {
  name = "eks-blueprints-demo"

  region   = "ap-southeast-2"
  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  nodes_additional_policies = {
    AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  }

  tags = {
    created-by = local.name
  }
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  create_igw           = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/elb"              = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/internal-elb"     = 1
    "karpenter.sh/discovery"              = local.name
  }

  tags = local.tags
}

################################################################################
# EKS Cluster Module
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.15"

  cluster_name                   = local.name
  cluster_version                = "1.27"
  cluster_endpoint_public_access = true
  cluster_enabled_log_types      = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  iam_role_name            = "${local.name}-cluster-role"
  iam_role_use_name_prefix = false

  kms_key_aliases = [local.name]

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  manage_aws_auth_configmap = true
  aws_auth_roles = [
    {
      rolearn  = data.aws_caller_identity.current.arn
      username = "cluster-admin"
      groups   = ["system:masters"]
    },
  ]

  eks_managed_node_groups = {
    managed = {
      name            = "${local.name}-eks_managed"
      use_name_prefix = false

      iam_role_name                = "${local.name}-eks_managed"
      iam_role_additional_policies = local.nodes_additional_policies
      iam_role_use_name_prefix     = false
      use_custom_launch_template   = false

      instance_types = ["t3.large"]
      capacity_type  = "SPOT"

      min_size     = 1
      max_size     = 2
      desired_size = 1

      subnet_ids = module.vpc.private_subnets

      labels = {
        Node = "managed"
      }
    }
  }

  self_managed_node_groups = {
    self_managed = {
      name            = "${local.name}-self_managed"
      use_name_prefix = false

      iam_role_name                = "${local.name}-self_managed"
      iam_role_additional_policies = local.nodes_additional_policies
      iam_role_use_name_prefix     = false

      launch_template_name            = "self_managed-${local.name}"
      launch_template_use_name_prefix = false

      instance_type = "t3.medium"
      capacity_type = "SPOT"

      min_size     = 1
      max_size     = 2
      desired_size = 1

      subnet_ids = module.vpc.private_subnets

      labels = {
        Node = "self-managed"
      }
    }
  }

  fargate_profiles = {
    fargate = {
      iam_role_name                = "${local.name}-fargate"
      iam_role_additional_policies = local.nodes_additional_policies
      iam_role_use_name_prefix     = false

      subnet_ids = module.vpc.private_subnets

      selectors = [{
        namespace = "karpenter"
      }]

      labels = {
        Node = "fargate"
      }
    }
  }

  tags = local.tags
}

################################################################################
# EKS Blueprints Addons Modules
################################################################################

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.1"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # eksctl utils describe-addon-versions --kubernetes-version 1.27 | grep AddonName
  # some require subscription in marketplace
  eks_addons = {
    coredns = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
    kubecost_kubecost = {
      most_recent = true
      preserve    = false
    }
  }

  # enable_aws_load_balancer_controller = true
  # enable_karpenter                    = true
  enable_metrics_server = true
  # enable_fargate_fluentbit            = true

  tags = local.tags
}

################################################################################
# EKS Blueprints Teams Modules
################################################################################

module "eks_blueprints_admin_team" {
  source  = "aws-ia/eks-blueprints-teams/aws"
  version = "~> 1.0"

  name = "team-admin"

  enable_admin = true
  users        = [data.aws_caller_identity.current.arn]
  cluster_arn  = module.eks.cluster_arn

  tags = local.tags
}

module "eks_blueprints_dev_teams" {
  source  = "aws-ia/eks-blueprints-teams/aws"
  version = "~> 1.0"

  for_each = {
    app-01 = {
      users = [data.aws_caller_identity.current.arn]
      labels = {
        data-classification = "public"
      }

    }
    app-02 = {
      users = [data.aws_caller_identity.current.arn]
      labels = {
        data-classification = "internal"
      }
    }
    app-03 = {
      users = [data.aws_caller_identity.current.arn]
      labels = {
        data-classification = "protected"
      }
    }
  }

  name = "team-${each.key}"

  users             = each.value.users
  cluster_arn       = module.eks.cluster_arn
  oidc_provider_arn = module.eks.oidc_provider_arn

  labels = {
    team = each.key
  }

  annotations = {
    team = each.key
  }

  namespaces = {
    "team-${each.key}" = {
      labels = merge(
        {
          team = each.key
        },
        try(each.value.labels, {})
      )

      resource_quota = {
        hard = {
          "requests.cpu"    = "2000m",
          "requests.memory" = "4Gi",
          "limits.cpu"      = "4000m",
          "limits.memory"   = "16Gi",
          "pods"            = "20",
          "secrets"         = "20",
          "services"        = "20"
        }
      }

      limit_range = {
        limit = [
          {
            type = "Pod"
            max = {
              cpu    = "200m"
              memory = "1Gi"
            }
          },
          {
            type = "PersistentVolumeClaim"
            min = {
              storage = "24M"
            }
          },
          {
            type = "Container"
            default = {
              cpu    = "50m"
              memory = "24Mi"
            }
          }
        ]
      }
    }
  }

  tags = local.tags
}

################################################################################
# Outputs
################################################################################

output "eks_blueprints_demo_cluster_admin_kubectl_configuration" {
  description = "Configure kubectl for cluster admin"
  value       = "aws eks --region ${local.region} update-kubeconfig --name ${module.eks.cluster_name}"
}

output "eks_blueprints_demo_cluster_cost_dashboard" {
  description = "View Kubecost dashboard"
  value       = "kubectl port-forward --namespace kubecost deployment/cost-analyzer 9090"
}
