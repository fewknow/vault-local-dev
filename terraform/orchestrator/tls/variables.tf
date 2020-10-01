variable "vault_token" {  
  description = "Vault token"
}

# This is the application name that will be used to create the tls backend role.
variable "app" {
  description = "Application / Deployable unit name"
}