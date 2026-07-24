terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 6.23.0"
      configuration_aliases = [aws.org-management]
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0.0"
    }
  }
}
