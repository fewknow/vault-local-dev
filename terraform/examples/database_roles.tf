#THIS IS ALL APPLICATION DEFAULT ROLES TO MSSQL DEFAULT SERVER
resource "vault_database_secret_backend_role" "business_support_it_dev_role" {
  backend             = data.terraform_remote_state.mssql.outputs.mssql_mount
  name                = "${var.app}-role"
  db_name             = data.terraform_remote_state.mssql.outputs.business_support_it_dev
  default_ttl         = 3600
  max_ttl             = 86400
  creation_statements = ["EXEC BusinessSupportIT.dbo.Vault_Create @username = '[{{name}}]', @password = '{{password}}'"]
}
