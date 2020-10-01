# locals {
#   _schemaversion = "1.0"
#   json_data      = jsondecode(file("${path.module}/policy.tpl"))
#   # Primarily in charge of translating JSON into a Terraform-readable map. Filters by matching schema version,
#   # datacenter and datacenter environment passed to the script.
#   policies = flatten([
#     for collection_key in keys(local.json_data) : [
#       for policy_collection in local.json_data["${collection_key}"].policies : [
#         for service in policy_collection.services : {
#           "_schemaversion"           = local.json_data["${collection_key}"]._schemaversion
#           "datacenter"               = policy_collection.datacenter
#           "environment"              = policy_collection.environment
#           "name"                     = service.name
#           "certificate_common_names" = try(service.certificate-common-names, [])
#           "active_directory"         = try(service.active-directory, [])
#           "database"                 = try(service.database, [])
#         }
#       ]
#       if policy_collection.datacenter == var.datacenter
#       && policy_collection.environment == var.datacenter_environment
#       && local.json_data["${collection_key}"]._schemaversion == local._schemaversion
#     ]
#   ])

#   policy_names = flatten([
#     for policy in local.policies : [
#       for key, value in policy : value if key == "name"
#     ]
#   ])
# }

# # HCL policy template to be generated based on the JSON policy documents
# resource "vault_policy" "policy_repository" {
#   count  = length(local.policies)
#   name   = "${local.policies[count.index].name}-policy"
#   policy = <<EOT
# %{for database_role in local.policies[count.index].database~}
# path "mssql/creds/${database_role}*" {
#     capabilities = ["read", "list"]
# }
# %{endfor~}
# %{if local.policies[count.index].certificate_common_names != []~}
# path "tls/issue/tls-issuer-role*" {
#     capabilities = ["update"]
#     allowed_parameters = {
#         "common_name" = [
#             "${join("\", \"", local.policies[count.index].certificate_common_names)}"
#         ]
#         "format" = []
#         "ttl" = []
#     }
# }
# %{endif~}
# path "auth/*" {
#     capabilities = ["create", "read", "update", "delete", "list", "sudo"]
# }
#     EOT
# }

resource "vault_policy" "App-policy" {
  name = "${var.app}-policy"

  policy = <<EOT
  path "auth/*" {
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
  }
  #Allow token to manage itself
  path "auth/token/create" {
    capabilities = [ "update" ]
  }

  # Allow creating dynamic db creds for this app
  path "mssql/creds/${var.app}*" {
    capabilities = ["read", "list", "create", "update"]
  }

  # Work read mssql secrets engine role config for this app
  path "mssql/roles/${var.app}*" {
    capabilities = [ "read", "list" ]
  }
  EOT
}

# resource "vault_policy" "mssql-policy" {
#   name = "mssql-provisioner-policy"

#   policy = <<EOT
# path "mssql/creds/${var.app}*" {
#     capabilities = ["read", "list", "create", "update"]
# }
# path "mssql/roles/${var.app}*" {
#     capabilities = ["read", "list", "create", "update"]
# }
# EOT
# }

resource "vault_policy" "tls-policy" {
  name = "tls-auth-issuer-role-policy"

  policy = <<EOT
path "cert/issue/tls-issuer-role*" {
    capabilities = ["update", "create", "delete", "read"]
    allowed_parameters = {
        "common_name" = [
            "${var.app}.com"
        ]
        "format" = []
        "ttl" = []
    }
}
EOT
}