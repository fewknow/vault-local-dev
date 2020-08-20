provider "vault" {
  # This will default to using $VAULT_ADDR
  token = var.vault_token
}


data "terraform_remote_state" "mssql" {
  backend = var.backend

  config = {
    subpath  = "vault/bootstrap/mssql"
    url      = "https://artifactory.qvcdev.qvc.net/artifactory"
    repo     = "terraform-states"
    username = "***artifactory username***"
    password = "***artifactory password***"
  }
}
