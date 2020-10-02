output "role_name" {
  value = vault_approle_auth_backend_role.role.role_name
}

output "role_id" {
  value = vault_approle_auth_backend_role.role.role_id
}

# output "secret_id" {
#   value = vault_approle_auth_backend_role_secret_id.role.secret_id
# }
