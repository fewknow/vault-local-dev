# Mount the appRole auth method
resource "vault_auth_backend" "approle" {
  type = "approle"
}

# Create a Role
resource "vault_approle_auth_backend_role" "role" {
  depends_on            = [vault_auth_backend.approle]
  backend               = "approle"
  role_name             = var.role_name
  #secret_id_num_uses    = 
  secret_id_ttl         = "300" # Five minutes
  token_policies        = [
    "default",
    "${var.role_name}-policy"
    ]
}

# Generate a secretID
# resource "vault_approle_auth_backend_role_secret_id" "role" {
#   backend               = "approle"
#   role_name             = vault_approle_auth_backend_role.role.role_name
# }

# Create files containing AppRoleID and SecretID
# resource "local_file" "role_id" {
#     content           = vault_approle_auth_backend_role.role.role_id
#     filename          = "../../../../_data/roleID"
#     file_permission   = "0600"
# }

# Get the secret_ID for out role
# resource "local_file" "secret_id" {
#     content           = vault_approle_auth_backend_role_secret_id.role.secret_id
#     filename          = "../../../../_data/secretID"
#     file_permission   = "0600"
# }
