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

variable "db_name" {
  description = "Name for the database"
}

variable "sql_user" {
  description = "Name for the database admin"
  default     = "sa"
}

variable "sql_pass" {
  description = "Database password"
  default = "Testing123"
}

variable "sql_server_ip" {
  description = "Ip for the database"
  default     = "mssql"
}