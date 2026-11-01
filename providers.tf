provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Repository  = "Human-Gechi/cob_cicd"
      Environment = var.environment
    }
  }
}
