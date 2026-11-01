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

    user_data = <<-EOT
    #!/bin/bash
    set -euxo pipefail
    dnf install -y nginx
    echo '${base64encode(file("${path.module}/website/index.html"))}' | base64 -d > /usr/share/nginx/html/index.html
    systemctl enable --now nginx
  EOT
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