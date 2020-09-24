variable "app" {
  description = "name of application that will be used for policy and certificate creation"
}

variable "vault_token" {
  description = "Provisioner token for app polcies"
}

variable "backend" {
  description = "Type of backend (consul, artifactory)"
}
