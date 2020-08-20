# This policy is going to allow the token bearer to manager ACLs for other entities
resource "vault_policy" "acl-provisioner-policy" {
  name = "acl-provisioner-policy"

  policy = <<EOT

    #Allow token to manage itself
    path "auth/token/create" {
      capabilities = [ "update" ]
    }

    # Create and manage ACL policies via API
    path "sys/policies/acl/*"
    {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }

  EOT
}
