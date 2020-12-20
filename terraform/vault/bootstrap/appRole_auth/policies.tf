# Policy to allow vault agent to generate provisioner tokens
# when updating something in vault.

resource "vault_policy" "app-prov-policy" {
  name = "approle-provisioner-policy"

  policy = <<EOT

    path "auth/token/create"
    {
      capabilities = ["update" , "create", "sudo"]
    }
    path "auth/token/lookup"
    {
      capabilities = ["read"]
    }
    path "auth/token/lookup-accessor"
    {
      capabilities = ["update"]
    }
    EOT
}

resource "vault_policy" "app-fetch-policy" {
  name = "approle-fetch-policy"

  policy = <<EOT
    path "auth/token/create"
    {
      capabilities = ["update" , "create", "sudo"]
    }
    path "auth/approle/role/${var.role_name}*"
    {
      capabilities = ["create", "update", "read"]
    }
    EOT
}