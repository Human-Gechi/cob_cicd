variable "aws_region" {
  type    = string
  default = "eu-north-1"
}

variable "organisation" {
  type    = string
  default = "beejan"
}

variable "project" {
  type    = string
  default = "mainwebsite"
}

variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "team" {
  type    = string
  default = "Engineering"
}

variable "extra_tags" {
  description = "COB requires at least one extra tag."
  type        = map(string)
  default = {
    CostCenter = "Software-Engineering"
  }
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "instance_count" {
  type    = number
  default = 1
}

variable "enable_database" {
  type        = bool
  default     = false
}