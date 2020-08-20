provider "vault" {
  token   = var.vault_token
  address = local.vault_location["${var.datacenter}${var.datacenter_environment}"]
}
