provider "vault" {
  address         = var.vault_addr
  token           = var.vault_token
  skip_tls_verify = false
  ca_cert_file    = "../../../../config/${var.env}.pem"
}

provider "local" {
  version = "~> 1.4"
}