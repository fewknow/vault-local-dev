# Manage the transit engine
resource "vault_policy" "transit_manage" {
  name   = "transit-admin-policy"
  policy = <<EOT
    path "transit/*" {
      capabilities = ["create", "update", "list", "read", "delete"]
    }
  EOT
}

# Use the engine
resource "vault_policy" "transit_user_pol" {
  name   = "transit-user-policy"
  policy = <<EOT
    path "transit/${var.transit_key_name}*" {
      capabilities = ["read", "update"]
    }
  EOT
}