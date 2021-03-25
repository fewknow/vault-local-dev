variable "transit_key_name" {
    description = "Transit key to create"
}

variable "vault_token" {
  description = "Default Vault Token"
}

variable "vault_addr" {
  description = "Address of the Vault instance being targeted"
}

variable "env" {
  description = "Environment"
}
