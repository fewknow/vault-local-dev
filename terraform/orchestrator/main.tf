provider "vault" {
  # This will default to using $VAULT_ADDR
  token = var.vault_token
}


data "terraform_remote_state" "apps" {
  backend = "consul"

  config = {
    path = "vault/apps"
  }
}

data "terraform_remote_state" "pki" {
  backend = "consul"

  config = {
    path = "vault/pki"
  }
}

data "terraform_remote_state" "authmethods" {
  backend = "consul"

  config = {
    path = "vault/authmethods"
  }
}
