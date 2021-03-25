output "cert_path" {
  value = vault_auth_backend.cert.path
}

output "role_policies" {
  value = vault_cert_auth_backend_role.project_cert.token_policies
}

output "vault_project_cert_role" {
  value = vault_cert_auth_backend_role.project_cert.name
}