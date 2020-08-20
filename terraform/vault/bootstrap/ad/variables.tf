variable "vault_token" {
  description = "Token used to authenticate with Vault"

}

variable "ad_binddn" {
  description = "Service account with the privileges to perform password rotation"
  #default = "sUS-D-Vault-Rotate"
}

variable "ad_bindpass" {
  description = "Service account password"
}

variable "ad_url" {
  description = "URL for QVC US Active Directory"
  #default = "ldaps://wchwdc612.qvcdev.qvc.net"
}

variable "ad_userdn" {
  description = "Location where to look for eligable accounts for password rotation"
  #default = "OU=HashiCorpVault,DC=qvcdev,DC=qvc,DC=net"
}

variable "ad_tlsminversion" {
  description = "Minimum tls standard to adhear to"
  #default = "tls10"
}

variable "vault_addr" {
  description = "Address of the Vault instance being targeted"
  #default = "https://vault1.dev.wc.vault.qvcdev.qvc.net:8200/"
}

variable "env" {
  description = "Environment for variables"
}
