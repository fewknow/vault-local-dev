# Manage the transform engine
resource "vault_policy" "transform_manage" {
  name   = "transform-admin-policy"
  policy = <<EOT
    path "transform/*" {
      capabilities = ["create", "update", "list", "delete"]
    }
  EOT
}

# Use the engine
resource "vault_policy" "transform_payments" {
  name   = "transform-payments-policy"
  policy = <<EOT
    path "transform/+/payments" {
      capabilities = ["update"]
    }
  EOT
}