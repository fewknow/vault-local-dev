provider "vault" {
  address         = var.vault_addr
  token           = var.vault_token
  skip_tls_verify = false
  ca_cert_file    = "../../../../certs/QVC-ENT-CA-01.pem"
}

