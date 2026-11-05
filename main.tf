module "network" {
  source = "git::https://github.com/Human-Gechi/cob_task.git//modules/networking"

  organisation = var.organisation
  project      = var.project
  environment  = var.environment
  team         = var.team
  extra_tags   = var.extra_tags

  vpc_cidr           = var.vpc_cidr
  az_count           = 2
  enable_nat_gateway = false
}

module "assets" {
  source = "git::https://github.com/Human-Gechi/cob_task.git//modules/storage"

  organisation = var.organisation
  project      = var.project
  environment  = var.environment
  team         = var.team
  extra_tags   = var.extra_tags

  name       = "site-assets"
  versioning = true

  lifecycle_rules = {
    expire-old-versions = {
      noncurrent_expire_days = 30
    }
  }
}

module "web" {
  source = "git::https://github.com/Human-Gechi/cob_task.git//modules/compute/ec2"

  organisation = var.organisation
  project      = var.project
  environment  = var.environment
  team         = var.team
  extra_tags   = var.extra_tags

  name           = "web"
  vpc_id         = module.network.vpc_id
  subnet_ids     = module.network.public_subnet_ids
  instance_type  = var.instance_type
  instance_count = var.instance_count

  user_data = templatefile("${path.module}/frontend/user_data.sh.tftpl", {
    index_html_b64 = base64encode(file("${path.module}/frontend/index.html"))
  })
}

data "aws_iam_policy_document" "web_assets_read" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [module.assets.bucket_arn]
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["${module.assets.bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "web_assets_read" {
  name   = "assets-read"
  role   = module.web.role_name
  policy = data.aws_iam_policy_document.web_assets_read.json
}

module "iam" {
  source = "git::https://github.com/Human-Gechi/cob_task.git//modules/iam"

  organisation = var.organisation
  project      = var.project
  environment  = var.environment
  team         = var.team
  extra_tags   = var.extra_tags

  team_access = {
    Engineering = {
      s3_write_arns = [module.assets.bucket_arn]
    }
  }
}

module "database" {
  count  = var.enable_database ? 1 : 0
  source = "git::https://github.com/Human-Gechi/cob_task.git//modules/database"

  organisation = var.organisation
  project      = var.project
  environment  = var.environment
  team         = var.team
  extra_tags   = var.extra_tags

  vpc_id                    = module.network.vpc_id
  private_subnet_ids        = module.network.private_subnet_ids
  allowed_security_group_id = module.web.security_group_id

  engine_version = "16"
  db_name        = "webapp"
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

data "aws_iam_policy_document" "runtime_permissions" {
  statement {
    sid    = "TerraformState"
    effect = "Allow"

    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      "arn:aws:s3:::${var.state_bucket}/cob-website/${var.environment}/*"
    ]
  }

  statement {
    sid    = "TerraformStateList"
    effect = "Allow"

    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.state_bucket}"]
  }

  statement {
    sid    = "ProjectBuckets"
    effect = "Allow"

    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::beejan-website-${var.environment}-*",
      "arn:aws:s3:::beejan-website-${var.environment}-*/*"
    ]
  }

  statement {
    sid    = "Network"
    effect = "Allow"

    actions   = ["ec2:*"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = ["eu-north-1"]
    }
  }

  statement {
    sid    = "AmiLookup"
    effect = "Allow"

    actions = ["ssm:GetParameter"]
    resources = [
      "arn:aws:ssm:eu-west-1::parameter/aws/service/ami-amazon-linux-latest/*"
    ]
  }

  statement {
    sid    = "ProjectIamRoles"
    effect = "Allow"

    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy"
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/beejan-website-${var.environment}-*"]
  }

  statement {
    sid    = "AttachOnlyApprovedPolicies"
    effect = "Allow"

    actions = ["iam:AttachRolePolicy"]
    resources = [
      "arn:aws:iam::${local.account_id}:role/beejan-website-${var.environment}-*"
    ]

    condition {
      test     = "ArnLike"
      variable = "iam:PolicyARN"
      values = [
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
        "arn:aws:iam::${local.account_id}:policy/beejan-website-${var.environment}-*"
      ]
    }
  }

  statement {
    sid    = "ProjectIamPolicies"
    effect = "Allow"

    actions = [
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy"
    ]
    resources = ["arn:aws:iam::${local.account_id}:policy/beejan-website-${var.environment}-*"]
  }

  statement {
    sid    = "ProjectInstanceProfiles"
    effect = "Allow"

    actions = [
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:UntagInstanceProfile"
    ]
    resources = ["arn:aws:iam::${local.account_id}:instance-profile/beejan-website-${var.environment}-*"]
  }

  statement {
    sid    = "PassRoleToEc2Only"
    effect = "Allow"

    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/beejan-website-${var.environment}-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }

  statement {
    sid    = "OptionalDatabase"
    effect = "Allow"

    actions   = ["rds:*"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = ["eu-north-1"]
    }
  }
}

resource "aws_iam_policy" "runtime_permissions" {
  name   = "${var.project}-${var.environment}-runtime-permissions"
  policy = data.aws_iam_policy_document.runtime_permissions.json
}

resource "aws_iam_role_policy_attachment" "web_runtime_permissions" {
  role       = module.web.role_name
  policy_arn = aws_iam_policy.runtime_permissions.arn
}
