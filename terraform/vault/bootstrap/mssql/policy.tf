
# THIS IS A PROVISIONER POLICY
resource "vault_policy" "mssql-provisioner-policy" {
  name = "mssql-provisioner-policy"

  policy = <<EOT

  #Allow token to manage itself
  path "auth/token/create" {
    capabilities = [ "update" ]
  }

  # Work with mssql secrets engine
  path "mssql/roles/*" {
    capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
  }

    EOT
}
