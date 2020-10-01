provider "vault" {
  # This will default to using $VAULT_ADDR
  token   = var.vault_token
  address = var.vault_addr
}

data "terraform_remote_state" "mssql" {
  backend = "consul"

  config = {
    path = "vault/mssql"
  }
}