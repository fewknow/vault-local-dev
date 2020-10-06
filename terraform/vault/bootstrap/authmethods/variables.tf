variable "vault_token" {
  description = "Default Vault Token"

}

variable "vault_addr" {
  description = "Default Vault Address"
}

variable "ldap_url" {
  type    = string
  default = "ldaps://test-ldap.testdomain.domain.net:636"
}

variable "ldap_userdn" {
  type    = string
  default = "DC=qvcdev,DC=qvc,DC=net"
}

variable "ldap_binddn" {
  type    = string
  default = ""
}

variable "ldap_bindpass" {
  type    = string
  default = ""
}

variable "ldap_tlsminversion" {
  type    = string
  default = ""
}

variable "ldap_certificate" {
  type    = string
  default = ""
}

variable "ldap_groupdn" {
  type    = string
  default = "CN=VaultAdmins,OU=Groups,DC=qvcdev,DC=qvc,DC=net"
}

variable "admin_policy_name" {
  type    = string
  default = "admin"
}

variable "env" {
}