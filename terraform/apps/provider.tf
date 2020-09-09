provider "vault" {
  token   = var.token
  address = local.vault_location["${var.datacenter}${var.datacenter_environment}"]
}
