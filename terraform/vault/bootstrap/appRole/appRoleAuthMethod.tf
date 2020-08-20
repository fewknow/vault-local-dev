# This is to enable to app role auth method to be used in jenkins
# this can and should also be used by any vault agent

resource "vault_approle_auth_backend_role" "jenkins" {
  backend               = "approle"
  role_name             = "jenkins-role"
  token_policies        = ["default", "vault-agent-policy"]
  secret_id_bound_cidrs = ["10.103.7.212/32"]
}

data "vault_approle_auth_backend_role_id" "jenkins" {
  backend               = "approle"
  role_name             = vault_approle_auth_backend_role.jenkins.role_name
  secret_id_bound_cidrs = ["10.103.7.212/32"]
}

resource "vault_approle_auth_backend_role_secret_id" "jenkins" {
  backend               = "approle"
  role_name             = vault_approle_auth_backend_role.jenkins.role_name
  secret_id_bound_cidrs = ["10.103.7.212/32"]
}

resource "null_resource" "role-id" {
  depends_on = [vault_approle_auth_backend_role_secret_id.jenkins]
  provisioner "local-exec" {
    command     = "vault read -format=json auth/approle/role/jenkins-role/role-id | jq  -r '.data.role_id' > roleID"
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "null_resource" "secret-id" {
  depends_on = [vault_approle_auth_backend_role_secret_id.jenkins]
  provisioner "local-exec" {
    command     = "vault write -f -format=json auth/approle/role/jenkins-role/secret-id | jq -r '.data.secret_id' > secretID"
    interpreter = ["/bin/bash", "-c"]
  }
}
