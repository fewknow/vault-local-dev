
# THIS IS A PROVISIONER POLICY for AD
resource "vault_policy" "ad-provisioner-policy" {
  name = "ad-provisioner-policy"

  policy = <<EOT

  #Allow token to manage itself
  path "auth/token/create" {
    capabilities = [ "update" ]
  }

  # Work with ad secrets engine
  path "ad/roles/*" {
    capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
  }

    EOT
}
