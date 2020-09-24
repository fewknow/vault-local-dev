variable "vault_token" {
  description = "Default Vault Token"
}

variable "vault_addr" {
  description = "Vault address"
}

variable "env" {
  description = "Env for terraform workspace. Could be removed in the future."
}

variable "encrypt" {
  description = "If database is encrypted enter in ?encrypt=disable else nothing"
  default     = "?encrypt=disable"
}

variable "business_support_it_dev_user" {
  description = "User name for MSSQL Business Support IT"
  default     = "Developer"
}

variable "business_support_it_dev_password" {
  description = "Password for MSSQL Business Support IT"
  default     = "Testing123"
}

variable "business_support_it_dev_ip" {
  description = "IP for dev business support IT"
  default     = "127.0.0.1"
}
