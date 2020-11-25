provider "vault" {
  # This will default to using $VAULT_ADDR
  token   = var.vault_token
  address = var.vault_addr
  #skip_tls_verify = true
  #ca_cert_file = var.ca_cert_file
}
