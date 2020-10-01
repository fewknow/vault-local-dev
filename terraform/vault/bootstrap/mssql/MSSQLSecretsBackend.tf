# THIS IS FOR DEFAULT APPLICATIONS
resource "vault_mount" "mssql" {
  path = "mssql"
  type = "database"
}


# ALL DATABASE CONNECTIONS NEED TO BE HERE.

# this needs to use REMOTE STATE to lookup apps
# resource "vault_database_secret_backend_connection" "business_support_it_dev" {
#   backend           = vault_mount.mssql.path
#   name              = "business-support-it-dev"
#   allowed_roles     = ["*"]
#   verify_connection = "false"

#   mssql {
#     connection_url = "sqlserver://{{username}}:{{password}}@${var.business_support_it_dev_ip}:1433${var.encrypt}"
#   }

#   data = {
#     username = var.business_support_it_dev_user
#     password = var.business_support_it_dev_password
#   }

# }

