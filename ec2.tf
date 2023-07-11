#####################################################################################################################################################################
###
### Summary : EC2
###
#####################################################################################################################################################################
# - Resource
#   - main
#     - EC2
#     - EIP
#     - AutoRecovery
#     - KMS
#   - sub 
#     - IAM role (Instance Profile)
#     - Security Group

#####################################################################################################################################################################
###
### data
###
#####################################################################################################################################################################
data "aws_ami" "al2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

#####################################################################################################################################################################
###
### Parameter
###
#####################################################################################################################################################################

locals {
  ec2_instance = {
    bastion = {
      base_ami            = data.aws_ami.al2.id
      instance_type       = "t3.micro"
      detailed_monitoring = false

      volume_type           = "gp3"
      volume_size           = 10
      iops                  = 3000 # default: 3000 gp2の場合は指定不可
      throughput            = 125  # iosp: 125 gp2の場合は指定不可
      delete_on_termination = true

      encrypted  = true
      kms_key_id = null # encrypted true でkms_key_idに null を指定した場合、デフォルトのKMSキーが使用される

      vpc_security_group_ids = [
        aws_security_group.ec2-bastion.id,
      ]
      subnet_id                   = aws_subnet.this["public-a"].id
      associate_public_ip_address = true # EIP を付ける場合には true を指定する必要がある
      associate_eip               = true
      private_ip                  = null

      newrelic = "${ var.env == "prd" ? "enabled" : "disabled"}"
      elb      = "none" # 接続するelbのtgを指定 elbに接続しない場合には"none"を指定する。
      billing  = "${ var.env == "prd" ? "3" : "0"}"
      ams_target_instanceid_vars = "${ var.env == "prd" ? "" : "no monitoring"}"
      ams_target_url_vars = "${ var.env == "prd" ? "" : "no monitoring"}"
      region = "ap-northeast-1" # AMSを使用する場合に指定する

      key_name  = "${var.account_name}_${var.env}_${var.aws_region}"
      user_data = file("${path.module}/ec2/userdata/${var.env}/amazonlinux2_bastion.sh") # 任意
    }
    web = {
      base_ami            = data.aws_ami.al2.id
      instance_type       = "t3.micro"
      detailed_monitoring = false

      volume_type           = "gp3"
      volume_size           = 10
      iops                  = 3000 # default: 3000 gp2の場合は指定不可
      throughput            = 125  # iosp: 125 gp2の場合は指定不可
      delete_on_termination = true

      encrypted  = true
      kms_key_id = null # encrypted true でkms_key_idに null を指定した場合、デフォルトのKMSキーが使用される

      vpc_security_group_ids = [
        aws_security_group.ec2-web.id,
      ]
      subnet_id                   = aws_subnet.this["protected-a"].id
      associate_public_ip_address = false # EIP を付ける場合には true を指定する必要がある
      associate_eip               = false
      private_ip                  = null

      newrelic = "${ var.env == "prd" ? "enabled" : "disabled"}"
      elb      = "none" # 接続するelbのtgを指定 elbに接続しない場合には"none"を指定する。
      billing  = "${ var.env == "prd" ? "3" : "0"}"
      ams_target_instanceid_vars = "${ var.env == "prd" ? "" : "no monitoring"}"
      ams_target_url_vars = "${ var.env == "prd" ? "" : "no monitoring"}"
      region = "ap-northeast-1" # AMSを使用する場合に指定する

      key_name  = "${var.account_name}_${var.env}_${var.aws_region}"
      user_data = file("${path.module}/ec2/userdata/${var.env}/amazonlinux2_web.sh") # 任意
    }
  }
  ec2_prefix_list = {
    ope = {
      dev = [
        aws_ec2_managed_prefix_list.this["cloudpack"].id,
        ]
      prd = [
        aws_ec2_managed_prefix_list.this["cloudpack"].id,
        aws_ec2_managed_prefix_list.this["ams"].id,
        aws_ec2_managed_prefix_list.this["newrelic"].id
      ]
    }
  }

  ec2_iam_roles = {
    bastion = {
      principals = ["ec2.amazonaws.com"],
      policys = [
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
      ]
    }
    web = {
      principals = ["ec2.amazonaws.com"],
      policys = [
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
      ]
    }

  }

}

#####################################################################################################################################################################
###
### main
###
#####################################################################################################################################################################

################################################
### EC2
################################################
resource "aws_instance" "this" {
  for_each = { for k, v in local.ec2_instance : k => v }

  ami                         = each.value.base_ami
  instance_type               = each.value.instance_type
  vpc_security_group_ids      = each.value.vpc_security_group_ids
  subnet_id                   = each.value.subnet_id
  iam_instance_profile        = aws_iam_instance_profile.ec2["${each.key}"].name
  private_ip                  = try(each.value.private_ip, null)
  associate_public_ip_address = each.value.associate_public_ip_address
  key_name                    = each.value.key_name
  monitoring                  = each.value.detailed_monitoring
  user_data                   = try(each.value.user_data, null)

  tags = {
    Name                        = "${var.project_name}-${var.env}-${each.key}"
    cloudpack_newrelic          = each.value.newrelic
    elb                         = each.value.elb
    IRET_BILLING_SERVICE        = each.value.billing
    ams_target_instanceid_vars  = each.value.ams_target_instanceid_vars
    ams_target_url_vars         = each.value.ams_target_url_vars
    region                      = each.value.region
  }

  root_block_device {
    volume_type           = each.value.volume_type
    volume_size           = each.value.volume_size
    iops                  = each.value.iops
    throughput            = each.value.throughput
    delete_on_termination = each.value.delete_on_termination

    encrypted  = each.value.encrypted
    kms_key_id = each.value.kms_key_id # encrypted true でkms_key_idを指定しない場合、デフォルトのKMSキーが使用される
  }

  volume_tags = {
    Name = "${var.project_name}-${var.env}-${each.key}-root"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

################################################
### EIP
################################################
resource "aws_eip" "eip" {
  for_each = toset([for k, v in local.ec2_instance : k if v.associate_eip == true])

  instance = lookup(aws_instance.this, each.value, null).id
  vpc      = true

  tags = {
    Name = "${var.project_name}-${var.env}-eip-${each.value}"
  }
}

################################################
### AutoRecovery
################################################
resource "aws_cloudwatch_metric_alarm" "autorecovery" {
  for_each = { for k, v in aws_instance.this : k => v.id }

  alarm_name          = "${var.project_name}-${var.env}-${each.value}-autorecovery"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed_System"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = each.value
  }

  alarm_actions = [
    "arn:aws:automate:${var.aws_region}:ec2:recover"
  ]

  depends_on = [aws_instance.this]
}

# KMS
# TODO: KMS不要な場合に作成しないように制御できるか
# resource "aws_kms_key" "ec2-ebs" {
#   description         = "KMS Key for EC2 EBS"
#   enable_key_rotation = true
# }

# resource "aws_kms_alias" "ec2-ebs" {
#   target_key_id = aws_kms_key.ec2-ebs.arn
#   name          = "alias/${var.project_name}-${var.env}-ec2-ebs"
# }

#####################################################################################################################################################################
###
### sub
###
#####################################################################################################################################################################
################################################
### IAM Role
################################################

data "aws_iam_policy_document" "ec2" {
  for_each = local.ec2_iam_roles

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"

      identifiers = each.value.principals
    }
  }
}

resource "aws_iam_role" "ec2" {
  for_each = local.ec2_iam_roles

  name               = "${var.project_name}-${var.env}-role-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.ec2[each.key].json
}

resource "aws_iam_instance_profile" "ec2" {
  for_each = local.ec2_iam_roles

  name = aws_iam_role.ec2["${each.key}"].name
  role = aws_iam_role.ec2["${each.key}"].name
}

# TODO : インスタンスが増えるごとにアタッチを増やす必要があるので、１つのリソースで全てアタッチできるようにする
resource "aws_iam_role_policy_attachment" "ec2_bastion" {
  for_each = toset(local.ec2_iam_roles.bastion.policys)

  role       = aws_iam_role.ec2["bastion"].name
  policy_arn = each.value
}

resource "aws_iam_role_policy_attachment" "ec2_web" {
  for_each = toset(local.ec2_iam_roles.web.policys)

  role       = aws_iam_role.ec2["web"].name
  policy_arn = each.value
}



################################################
### Security Group
################################################
### Bastion
resource "aws_security_group" "ec2-bastion" {
  name        = "${var.project_name}-${var.env}-sg-ec2-bastion"
  description = "${var.project_name} Security group for Bastion server"
  vpc_id      = aws_vpc.this.id

  #ssh
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    prefix_list_ids = var.env == "prd" ? local.ec2_prefix_list.ope.prd : local.ec2_prefix_list.ope.dev
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  tags = {
    Name = "${var.project_name}-${var.env}-sg-ec2-bastion"
  }
}

### Web
resource "aws_security_group" "ec2-web" {
  name        = "${var.project_name}-${var.env}-sg-ec2-web"
  description = "${var.project_name} Security group for Web server"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    security_groups = [
      aws_security_group.alb_web.id
    ]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  tags = {
    Name = "${var.project_name}-${var.env}-sg-ec2-web"
  }
}