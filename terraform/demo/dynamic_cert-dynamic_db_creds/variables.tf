variable "vault_token" {
  description = "Default Vault Token"
}

variable "vault_addr" {
  description = "Vault address"
  default     = "https://localhost:8200"
}

variable "app" {
    description = "Application name we're using for this demo"
    #default     = "jenkins"
}

variable "server_ip" {
    description = "Application name we're using for this demo"
    default     = "mssql"
}

variable "sql_pass" {
    description = "sql password we're using for this demo"
    default     = "localhost"
}

variable "sql_user" {
    description = "sql user we're using for this demo"
    default     = "localhost"
}

variable "encrypt" {
  description = "If database is encrypted enter in ?encrypt=disable else nothing"
  default     = "?encrypt=disable"
}