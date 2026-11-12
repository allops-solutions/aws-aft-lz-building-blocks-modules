terraform {
  # terraform_data lifecycle preconditions (1.4+) and check blocks (1.9+).
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.79"
    }
  }
}
