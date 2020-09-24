# Providers

# TODO: THIS NEEDS TO BE UPDATED TO USE CONFIG FILE AND CLI PARAMETES
provider "consul" {
  address        = var.consul_addr
  token          = var.acl_master_token
  insecure_https = true
  scheme         = "https"
  datacenter     = "dc1"
}
