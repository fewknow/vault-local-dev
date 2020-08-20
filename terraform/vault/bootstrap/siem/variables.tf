variable "siem_address" {
  description = "IP address for SIEM"
  #   default     = "10.4.102.69"
}

variable "siem_socket_type" {
  description = "Socket type tcp/udp"
  default     = "tcp"
}

variable "siem_format" {
  description = "Format for audit log (json or jsonx)"
  default     = "json"
}

variable "siem_prefix" {
  description = "Prefix to add before actual log line"
}

variable "description" {
  description = "Description of auditing"
}

variable "vault_addr" {
  description = "Address of the main Vault instance"
}

variable "vault_token" {
  description = "Token used to authenticate with Vault"
}

variable "env" {
  description = "Terraform env for workspaces"
}
