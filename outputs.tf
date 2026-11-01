output "website_urls" {
  value = [for ip in module.web.public_ips : "http://${ip}"]
}

output "assets_bucket" {
  value = module.assets.bucket_name
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "data_team_role_arn" {
  value = module.iam.team_role_arns["Engineering"]
}

output "database_address" {
  value = one(module.database[*].address)
}