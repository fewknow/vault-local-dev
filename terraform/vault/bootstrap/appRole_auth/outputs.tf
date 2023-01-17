output "role_name" {
  value = vault_approle_auth_backend_role.role.role_name
}

output "appRole_fetch_token" {
  value = vault_token.fetch_approle.client_token
  sensitive = true
}

# output "role_id" {
#   value = vault_approle_auth_backend_role.role.role_id
# }

# output "secret_id" {
#   value = vault_approle_auth_backend_role_secret_id.role.secret_id
# }
