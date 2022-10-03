provider "aws" {
  version      = "~> 3.70.0"
  region       = var.region
  default_tags {
    tags = {
      Team        = var.TEAM
      Environment = var.ENVIRONMENT
      Repo        = var.CI_PROJECT_URL
    }
  }
}