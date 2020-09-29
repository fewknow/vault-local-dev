# Enable the cert auth backend
resource "vault_auth_backend" "cert" {
  type = "cert"
  path = "cert"
}

# Create a role for authentication
resource "vault_cert_auth_backend_role" "project_cert" {
    depends_on     = [vault_auth_backend.cert]
    name           = var.env
    certificate    = file("../../../../config/${var.env}.pem")
    backend        = vault_auth_backend.cert.path
    #allowed_names  = ["foo.example.org", "baz.example.org"]
    token_ttl      = 300
    token_max_ttl  = 600
    token_policies = ["admin_cert_auth"]
}

