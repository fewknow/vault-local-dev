/*
This setups the ad role for the application. 
You will need to update the service_account_name field with the service account name.
The service account has to be in the ou=HashiCorpVault in order for this to work.
*/
resource "vault_generic_secret" "example" {
  path = "ad/roles/${var.app}-role"

  # The username must match the userPrincipalName for example username@qvcdev.qvc.net.
  data_json = <<EOT
{
  "service_account_name": "usernameExample@qvcdev.qvc.net"
}
EOT
}
