# https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/transit_secret_backend_cache_config
# Mount the engine
resource "vault_mount" "transit_mount" {
  path                      = "transit"
  type                      = "transit"
  description               = "Transit Secrets Engine"
  default_lease_ttl_seconds = 3600
  max_lease_ttl_seconds     = 86400
}

# Create a config for the Transit engine
resource "vault_transit_secret_cache_config" "cfg" {
  backend = vault_mount.transit_mount.path
  size    = 500
}

# Create an encryption key
resource "vault_transit_secret_backend_key" "key" {
  backend = vault_mount.transit_mount.path
  name    = var.transit_key_name
  deletion_allowed = true 
  exportable = true 
  # derived = var.derived
  # convergent_encryption = var.convergent_encryption 
}