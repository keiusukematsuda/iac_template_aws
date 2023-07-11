#####################################################################################################################################################################
###
### Summary : VPC
###
#####################################################################################################################################################################
# - Resource
#   - main
#     - VPC
#     - Subnets
#     - Internet GW
#     - NAT GW
#     - EIP
#     - Route Table
#     - Prefix List


#####################################################################################################################################################################
###
### Parameter
###
#####################################################################################################################################################################

locals {
  # VPC 
  vpc = {
    cidr = "172.16.0.0/16"
  }
  # Subnets
  subnets = {
    public-a = {
      subnet_cidr       = cidrsubnet(local.vpc.cidr, 4, 0)
      availability_zone = "ap-northeast-1a"
    }
    public-c = {
      subnet_cidr       = cidrsubnet(local.vpc.cidr, 4, 1)
      availability_zone = "ap-northeast-1c"
    }
    protected-a = {
      subnet_cidr       = cidrsubnet(local.vpc.cidr, 4, 4)
      availability_zone = "ap-northeast-1a"
    }
    protected-c = {
      subnet_cidr       = cidrsubnet(local.vpc.cidr, 4, 5)
      availability_zone = "ap-northeast-1c"
    }
    private-a = {
      subnet_cidr       = cidrsubnet(local.vpc.cidr, 4, 8)
      availability_zone = "ap-northeast-1a"
    }
    private-c = {
      subnet_cidr       = cidrsubnet(local.vpc.cidr, 4, 9)
      availability_zone = "ap-northeast-1c"
    }
  }
  # NAT GW
  natgw = {
    is_redundant = 0 # NAW GWを冗長する場合は1、しない場合は0
  }

  # Prefix List
  prefix_lists = {
    # Cloudpack (https://iret.docbase.io/posts/666659)
    cloudpack = {
      ty2         = "210.227.234.114/32"
      os1         = "211.16.30.174/32"
      jump-linux  = "54.64.137.251/32"
      jump-win    = "54.64.174.233/32"
    }
    # AMS (https://aws-plus.backlog.jp/alias/wiki/1074575312)
    ams = [
      "52.192.136.37/32",
      "52.192.136.65/32",
      "52.192.81.83/32",
      "54.238.111.59/32",
      "54.95.93.135/32",
      "35.167.175.162/32",
      "52.11.56.10/32",
      "52.26.135.139/32",
      "52.34.150.149/32",
      "54.214.172.165/32"
    ]
    # NewRelic (https://docs.newrelic.com/jp/docs/synthetics/synthetic-monitoring/administration/synthetic-public-minion-ips/)
    newrelic = [
      "35.79.233.64/26",
      "35.79.233.128/28",
      "35.77.208.0/24"
    ]
  }
}

#####################################################################################################################################################################
###
### main
###
#####################################################################################################################################################################

################################################
### VPC
################################################
resource "aws_vpc" "this" {
  cidr_block           = local.vpc.cidr
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"

  tags = {
    Name = "${var.project_name}-${var.env}-vpc"
  }
}

################################################
### Subnet
################################################
resource "aws_subnet" "this" {
  for_each = local.subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.subnet_cidr
  availability_zone = each.value.availability_zone

  tags = {
    Name = "${var.project_name}-${var.env}-subnet-${each.key}"
    Role = strrev(substr(strrev(each.key), 2, -1))
  }
}

################################################
### Internet Gateway
################################################
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-${var.env}-igw"
  }
}

################################################
### NAT G/W
################################################
resource "aws_nat_gateway" "nat-a" {
  subnet_id     = aws_subnet.this["public-a"].id
  allocation_id = aws_eip.nat-a.id

  tags = {
    Name = "${var.project_name}-${var.env}-nat-a"
  }
}

resource "aws_nat_gateway" "nat-c" {
  count         = local.natgw.is_redundant
  subnet_id     = aws_subnet.this["public-c"].id
  allocation_id = aws_eip.nat-c[count.index].id

  tags = {
    Name = "${var.project_name}-${var.env}-nat-c"
  }
}

################################################
### EIP for NAT G/W
################################################
resource "aws_eip" "nat-a" {
  vpc = true
  tags = {
    Name = "${var.project_name}-${var.env}-eip-nat-a"
  }
}

resource "aws_eip" "nat-c" {
  count = local.natgw.is_redundant
  vpc   = true
  tags = {
    Name = "${var.project_name}-${var.env}-eip-nat-c"
  }
}

################################################
### Route Table
################################################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.project_name}-${var.env}-rtb-public"
  }
}

resource "aws_route_table" "protected-a" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-a.id
  }

  tags = {
    Name = "${local.natgw.is_redundant == 1 ? "${var.project_name}-${var.env}-rtb-protected-a" : "${var.project_name}-${var.env}-rtb-protected"}"
  }
}

resource "aws_route_table" "protected-c" {
  count  = local.natgw.is_redundant
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-c[count.index].id
  }

  tags = {
    Name = "${var.project_name}-${var.env}-rtb-protected-c"
  }
}


resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-${var.env}-rtb-private"
  }
}

###  Associatie Route table with subnet
resource "aws_route_table_association" "public" {
  for_each = { for k, v in aws_subnet.this : k => v if v.tags.Role == "public" }

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "protected-a" {
  subnet_id      = aws_subnet.this["protected-a"].id
  route_table_id = aws_route_table.protected-a.id
}

resource "aws_route_table_association" "protected-c" {
  subnet_id      = aws_subnet.this["protected-c"].id
  route_table_id = local.natgw.is_redundant == 1 ? aws_route_table.protected-c[0].id : aws_route_table.protected-a.id
}

resource "aws_route_table_association" "private" {
  for_each = { for k, v in aws_subnet.this : k => v if v.tags.Role == "private" }

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

################################################
### prefix List
################################################
resource "aws_ec2_managed_prefix_list" "this" {
  for_each = local.prefix_lists

  name           = "${var.project_name}-${var.env}-pl-${each.key}"
  address_family = "IPv4"
  max_entries    = length(each.value) # TODO: 追加のたびに再作成になってしまう

  dynamic "entry" {
    for_each = { for k, v in each.value : k => v }

    content {
      cidr        = entry.value
      description = entry.key
    }
  }
}