output "path" {
  value = vault_auth_backend.cert.path
}

output "policies" {
  value = [vault_policy.tls-auth-certificate-issuer-policy.name,vault_policy.tls-auth-issuer-role-policy.name,vault_policy.admin-cert-policy.name]
}