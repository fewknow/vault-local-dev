provider "vault" {
  # This will default to using $VAULT_ADDR
  token   = var.vault_token
  address = var.vault_addr
}

resource "tls_private_key" "example" {
  algorithm = "ECDSA"
}