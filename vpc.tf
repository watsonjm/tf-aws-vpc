data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_availability_zones" "all" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}
resource "aws_vpc" "mainvpc" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  enable_classiclink   = var.enable_classiclink
  instance_tenancy     = "default"

  tags = merge(var.common_tags, { Name = var.name })
}

resource "aws_flow_log" "mainvpc" {
  count                    = var.flow_logs ? 1 : 0
  iam_role_arn             = aws_iam_role.flow_logs[0].arn
  log_destination          = aws_cloudwatch_log_group.flow_logs[0].arn
  traffic_type             = "ALL"
  max_aggregation_interval = 60
  vpc_id                   = aws_vpc.mainvpc.id

  tags = merge(var.common_tags, { Name = "${var.tag_prefix}-vpc-flow-logs" })
}

resource "aws_iam_role" "flow_logs" {
  count = var.flow_logs ? 1 : 0
  name  = "${var.tag_prefix}-vpc-flow-logs"

  assume_role_policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [{
		"Sid": "",
		"Effect": "Allow",
		"Principal": {
			"Service": "vpc-flow-logs.amazonaws.com"
		},
		"Action": "sts:AssumeRole",
		"Condition": {
			"StringEquals": {
				"aws:SourceAccount": "${data.aws_caller_identity.current.account_id}"
			},
			"ArnLike": {
				"aws:SourceArn": "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:vpc-flow-log/*"
			}
		}
	}]
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
      "Resource": "${aws_cloudwatch_log_group.flow_logs.0.arn}"
    }
  ]
}
EOF
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  count      = var.flow_logs ? 1 : 0
  name       = "${var.tag_prefix}-vpc-flow-logs"
  kms_key_id = var.kms_key_arn

  tags = merge(var.common_tags, { Name = "${var.tag_prefix}-vpc-flow-logs" })
}

####################################
# DEFAULT RESOURCES
####################################
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.mainvpc.id

  tags = merge(var.common_tags, {
    Name             = "${var.tag_prefix}-default-sg",
    default_resource = true
  })
}

resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.mainvpc.main_route_table_id

  tags = merge(var.common_tags, {
    Name             = "${var.tag_prefix}-default-rt",
    default_resource = true
  })
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

  tags = {
    Name             = "${var.tag_prefix}-default-nacl",
    default_resource = true
  }
}

####################################
# DEFAULT RESOURCES IN DEFAULT VPC
####################################
# Terraform is looking for default resources security reasons
# Terraform will set a Name tag along with various network settings
# to increase security (e.g. default subnets - no auto public ip)
#tfsec:ignore:aws-vpc-no-default-vpc
resource "aws_default_vpc" "default_vpc" {
  tags = {
    Name             = "Default VPC",
    default_resource = true
  }
}

resource "aws_default_subnet" "default_vpc" {
  for_each                = toset(data.aws_availability_zones.all.names)
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = {
    Name             = "Default subnet for ${each.key} in default VPC",
    default_resource = true
  }
}

resource "aws_default_security_group" "default_vpc" {
  vpc_id = aws_default_vpc.default_vpc.id

  tags = {
    Name             = "Default Security Group for default VPC",
    default_resource = true
  }
}

resource "aws_default_route_table" "default_vpc" {
  default_route_table_id = aws_default_vpc.default_vpc.main_route_table_id

  tags = {
    Name             = "Default Route Table for default VPC",
    default_resource = true
  }
}

resource "aws_default_network_acl" "default_vpc" {
  default_network_acl_id = aws_default_vpc.default_vpc.default_network_acl_id

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = aws_default_vpc.default_vpc.cidr_block
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

  tags = {
    Name             = "Default NACL for default VPC",
    default_resource = true
  }
}

data "aws_internet_gateway" "default_vpc" {
  filter {
    name   = "attachment.vpc-id"
    values = [aws_default_vpc.default_vpc.id]
  }
}

resource "aws_ec2_tag" "default_vpc_default_igw" {
  resource_id = data.aws_internet_gateway.default_vpc.internet_gateway_id
  key         = "Name"
  value       = "Default IGW for default VPC"
}

resource "aws_ec2_tag" "default_vpc_default_igw2" {
  resource_id = data.aws_internet_gateway.default_vpc.internet_gateway_id
  key         = "default_resource"
  value       = "true"
}