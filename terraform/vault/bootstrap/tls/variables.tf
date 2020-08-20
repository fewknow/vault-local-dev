variable "vault_token" {
  description = "Default Vault Token."
}

variable "vault_addr" {
  description = "Address of the Vault instance being targeted"
}

variable "venafi_policy_name" {
  description = "The name of the Venafi policy"
}

variable "venafi_user" {
  description = "Venafi service account username"
}

variable "venafi_password" {
  description = "Venafi service account password"
}

variable "venafi_address" {
  description = "Address of the Venafi instance being targeted"
  default     = "https://venafi.qvcdev.qvc.net:443/vedsdk"
}

variable "venafi_policy_zone_tls" {
  description = "Venafi platform policy name"
}

variable "env" {
  description = "Terraform workspace env"
}


variable "venafi_certificate_path" {
  description = "Venafi PEM bundle certificate path"
}
