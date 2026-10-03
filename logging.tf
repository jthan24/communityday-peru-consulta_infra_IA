# ------------------------------------------------------------------------------
# 1. IAM ROLE FOR SERVICE ACCOUNTS (IRSA) - FLUENT BIT
# ------------------------------------------------------------------------------
# OIDC Issuer data source desde tu clúster de EKS
data "aws_iam_policy_document" "fluentbit_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:amazon-cloudwatch:fluent-bit"]
    }

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
  }
}

resource "aws_iam_role" "fluentbit" {
  name               = "${var.cluster_name}-fluentbit-role"
  assume_role_policy = data.aws_iam_policy_document.fluentbit_assume_role.json
}

# Política gestionada por AWS para CloudWatch Agent / FluentBit
resource "aws_iam_role_policy_attachment" "fluentbit_CloudWatchAgentServerPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.fluentbit.name
}

# Provider de OIDC para EKS (Requerido para IRSA)
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# ------------------------------------------------------------------------------
# 2. HELM RELEASE: AWS FOR FLUENT BIT
# ------------------------------------------------------------------------------
provider "helm" {
  kubernetes = {
    config_path = "kubeconfig"
  }
}

resource "helm_release" "fluent_bit" {
  name             = "aws-for-fluent-bit"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-for-fluent-bit"
  namespace        = "amazon-cloudwatch"
  create_namespace = true

  values = [
    yamlencode({
      serviceAccount = {
        create = true
        name   = "fluent-bit"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.fluentbit.arn
        }
      }
      cloudWatchLogs = {
        enabled        = true
        region         = var.aws_region
        logGroupName   = "/aws/eks/${var.cluster_name}/application-logs"
        autoCreateGroup = true
      }
    })
  ]

  depends_on = [
    aws_eks_node_group.main,
    aws_iam_role_policy_attachment.fluentbit_CloudWatchAgentServerPolicy
  ]
}