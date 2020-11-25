provider "vault" {
  address         = var.vault_addr
  token           = var.vault_token
  skip_tls_verify = true
}

