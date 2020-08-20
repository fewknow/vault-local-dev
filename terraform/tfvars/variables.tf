variable "backend" {
  type    = string
  default = "consul"
}

variable "consul_addr" {
  description = "Consul address for state"
  type        = string
}

variable "vault_addr" {
  description = "Vault address"
  type        = string
}

variable "business_support_it_dev_ip" {
  description = "IP of mssql server"
  type        = string
}

variable "business_support_it_dev_user" {
  description = "Username for mssql server login"
  type        = string
}

variable "business_support_it_dev_password" {
  description = "Password for mssql server"
  type        = string
}

variable "ldap_binddn" {
  description = "DN of object to bind when performing user search"
  type        = string
}

variable "ldap_bindpass" {
  description = "Password to use with binddn when performing user search"
  type        = string
}

variable "ldap_url" {
  description = "The URL of the LDAP server"
  type        = string
}

variable "ldap_userdn" {
  description = "Base DN under which to perform user search"
  type        = string
}

variable "ldap_tlsminversion" {
  description = "Minimum acceptable version of TLS"
  type        = string
}

variable "ad_url" {
  description = "URL for QVC US Active Directory"
  type        = string
}

variable "ad_binddn" {
  description = "DN of object to bind when performing user search"
  type        = string
}

variable "ad_bindpass" {
  description = "Password to use with binddn when performing user search"
  type        = string
}

variable "ad_userdn" {
  description = "Base DN under which to perform user search"
  type        = string
}

variable "ad_tlsminversion" {
  description = "Minimum acceptable version of TLS"
  type        = string
}
