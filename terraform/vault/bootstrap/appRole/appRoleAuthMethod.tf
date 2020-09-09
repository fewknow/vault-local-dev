# This is to enable to app role auth method to be used in jenkins
# this can and should also be used by any vault agent

resource "vault_approle_auth_backend_role" "jenkins" {
  backend               = "approle"
  role_name             = "jenkins-role"
  token_policies        = ["default", "vault-agent-policy"]
  # secret_id_bound_cidrs = []
}

data "vault_approle_auth_backend_role_id" "jenkins" {
  backend               = "approle"
  role_name             = vault_approle_auth_backend_role.jenkins.role_name
  # secret_id_bound_cidrs = []
}

resource "vault_approle_auth_backend_role_secret_id" "jenkins" {
  backend               = "approle"
  role_name             = vault_approle_auth_backend_role.jenkins.role_name
  # secret_id_bound_cidrs = []
}

# Create files containing Jenkins AppRoleID and SecretID
resource "local_file" "role_id" {
    content           = data.vault_approle_auth_backend_role_id.jenkins.role_id
    filename          = "./roleID"
    file_permission   = "0600"
}

resource "local_file" "secret_id" {
    content           = vault_approle_auth_backend_role_secret_id.jenkins.secret_id
    filename          = "./secretID"
    file_permission   = "0600"
}
