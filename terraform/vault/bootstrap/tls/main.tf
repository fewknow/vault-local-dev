provider "vault" {
  # This will be the token from Vault
  token   = var.vault_token
  address = var.vault_addr
  # This will default to using $VAULT_ADDR
  # But can be set explicitly
  # address = "https://localhost:8200"
}
