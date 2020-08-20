output "role-id" {
  value = data.vault_approle_auth_backend_role_id.jenkins.role_id
}

output "secret-id" {
  value = vault_approle_auth_backend_role_secret_id.jenkins.secret_id
}
