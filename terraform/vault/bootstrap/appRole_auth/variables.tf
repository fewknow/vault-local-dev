variable "env" {
  description = "Env for terraform workspace. Could be removed in the future."
}

variable "vault_token" {
  description = "The token used against Vault through the Terraform provider."
}

variable "vault_addr" {
  description = "Address to the Vault Host"
}

variable "role_name" {
  description = "appRole to create"
}
