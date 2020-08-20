# tls-auth-certificate-issuer-policy is a provisioner policy
resource "vault_policy" "tls-auth-certificate-issuer-policy" {
  name   = "tls-auth-certificate-issuer-policy"
  policy = <<EOT
      #Allow token to manage itself
      path "auth/token/create" {
        capabilities = [ "update" ]
      }

      # Work with tls-auth secrets engine
      path "tls-auth/issue*" {
        capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
      }

      # Create, update, and delete auth methods
      path "auth/cert/*"
      {
        capabilities = ["read", "update"]
      }
  EOT
}


# tls-auth-issuer-role-policy is a provisioner policy
resource "vault_policy" "tls-auth-issuer-role-policy" {
  name   = "tls-auth-issuer-role-policy"
  policy = <<EOT
  #Allow token to manage itself
  path "auth/token/create" {
    capabilities = [ "update" ]
  }
  # Work with tls-auth secrets engine
  path "tls-auth/issue/tls-auth-issuer-role" {
    capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
  }
  EOT
}
