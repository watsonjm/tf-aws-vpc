# What is this?
Opinionated module to create a generic VPC and adopt default resources (e.g. default NACL).

## Example
```
kms_default_access = [
  "user/iam_user",
  "user/iam_user2",
]

locals {
  name_tag = "${var.project}-${var.environment}"
  kms_default_access = concat(
    ["${local.iam_arn_prefix}:root"],
    formatlist("${local.iam_arn_prefix}:%s", var.kms_default_access)
  )
  iam_arn_prefix = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}"
  arn_prefix     = { for each in local.arn_list : each => "arn:${data.aws_partition.current.partition}:${each}:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}" }
  arn_list = [
    "ec2",
    "eks",
    "kms",
    "logs",
  ]
}

module "vpc" {
  source               = "./module/vpc/"
  name                 = "${local.name_tag}-vpc"
  tag_prefix           = local.name_tag
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_classiclink   = false
  flow_logs            = true
  kms_key_arn          = aws_kms_key.keys["vpc_flow_logs"].arn
}

# key policy
data "aws_iam_policy_document" "vpc_flow_logs_kms" {
  statement {
    sid       = "Enable IAM User Permissions"
    actions   = ["kms:*"]
    resources = ["*"]
    effect    = "Allow"
    principals {
      type        = "AWS"
      identifiers = local.kms_default_access
    }
  }
  statement {
    sid = "AllowFull"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["*"]
    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["${local.arn_prefix["logs"]}:log-group:*", ]
    }
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "logs.${data.aws_region.current.name}.amazonaws.com",
        "delivery.logs.amazonaws.com"
      ]
    }
  }
}