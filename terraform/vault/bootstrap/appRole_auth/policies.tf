# Policy to allow vault agent to generate provisioner tokens
# when updating something in vault.

resource "vault_policy" "apps-policy" {
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
