data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

resource "aws_vpc" "mainvpc" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  enable_classiclink   = var.enable_classiclink
  instance_tenancy     = "default"

  tags = merge(var.common_tags, { Name = var.name })
}

resource "aws_flow_log" "mainvpc" {
  count           = var.flow_logs ? 1 : 0
  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.mainvpc.id

  tags = merge(var.common_tags, { Name = "${var.tag_prefix}-vpc-flow-logs" })
}

resource "aws_iam_role" "flow_logs" {
  count = var.flow_logs ? 1 : 0
  name  = "${var.tag_prefix}-flow-logs"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = merge(var.common_tags, { Name = "${var.tag_prefix}-vpc-flow-logs-role" })
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.flow_logs ? 1 : 0
  name  = "${var.tag_prefix}-vpc-flow-logs"
  role  = aws_iam_role.flow_logs[0].id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Effect": "Allow",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:SourceAccount": "${data.aws_caller_identity.current.account_id}"
        },
        "ArnLike": {
          "aws:SourceArn": "${aws_cloudwatch_log_group.flow_logs.0.arn}"
        }
      }
    }
  ]
}
EOF
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  count      = var.flow_logs ? 1 : 0
  name       = "${var.tag_prefix}-vpc-flow-logs"
  kms_key_id = var.kms_key_id

  tags = merge(var.common_tags, { Name = "${var.tag_prefix}-vpc-flow-logs" })
}

###########################
# DEFAULT RESOURCES
###########################
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.mainvpc.id

  ingress {
    protocol  = -1 #-1 = all 
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "${var.tag_prefix}-default-sg" })
}

resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.mainvpc.main_route_table_id

  tags = merge(var.common_tags, { Name = "${var.tag_prefix}-default-rt" })
}

resource "aws_default_network_acl" "default" {
  default_network_acl_id = aws_vpc.mainvpc.default_network_acl_id

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  lifecycle {
    ignore_changes = [subnet_ids]
  }

  tags = merge(var.common_tags, { Name = "${var.tag_prefix}-default-nacl" })
}
