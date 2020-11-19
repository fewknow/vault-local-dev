# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

resource "aws_kms_key" "enterprise-key" {
  description             = "Local Vault Dev key for Enterpise AutoUnseal of Vault"
  deletion_window_in_days = 10
  tags                    = {
      "created_by" : "${var.creator}"
  }
}