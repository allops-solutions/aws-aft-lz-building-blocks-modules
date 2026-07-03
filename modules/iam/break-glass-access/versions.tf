terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
      # org-management -> AWSAFTExecution in the CT management account (us-east-1).
      # All break-glass resources live exclusively in us-east-1.
      configuration_aliases = [aws.org-management]
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
  }
}
