# https://www.vaultproject.io/docs/secrets/kmip
# Mount the engine
resource "vault_mount" "kmip_mount" {
  path = "kmip"
  type = "kmip"
}

# Configure the kmip endpoint
resource "vault_generic_endpoint" "kmip_configure" {
  depends_on           = [vault_mount.kmip_mount]
  path                 = "${vault_mount.kmip_mount.path}/config"
  ignore_absent_fields = true
  data_json = <<EOT
{
  "listen_addrs": "0.0.0.0:5696"
}
EOT
}

# Create a scope
resource "vault_generic_endpoint" "kmip_scope" {
  depends_on           = [vault_mount.kmip_mount]
  path                 = "${vault_mount.kmip_mount.path}/scope/${var.env}"
  ignore_absent_fields = true
  disable_read         = true
  data_json = <<EOT
{}
EOT
}

# Create a kmip role and assign operations
resource "vault_generic_endpoint" "kmip_role" {
  depends_on           = [vault_mount.kmip_mount]
  path                 = "${vault_mount.kmip_mount.path}/scope/${var.env}/role/admin"
  ignore_absent_fields = true
  disable_read         = true
  data_json = <<EOT
{
  "operation_all": true
}
EOT
}