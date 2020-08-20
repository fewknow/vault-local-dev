resource "vault_ldap_auth_backend" "ldap" {
  path            = "ldap"
  url             = var.ldap_url
  userdn          = var.ldap_userdn
  binddn          = var.ldap_binddn
  bindpass        = var.ldap_bindpass
  userattr        = "sAMAccountName"
  tls_min_version = var.ldap_tlsminversion
  discoverdn      = false
  # QVCUS AD uses the QVCMSCA CA. CA must be JSON-encoded into a string in order to be sent successfully
  certificate = var.ldap_certificate
  groupdn     = var.ldap_groupdn
  groupfilter = "(&(objectClass=group)(member:1.2.840.113556.1.4.1941:={{.UserDN}}))"
}
resource "vault_identity_group" "vault_admins" {
  name     = "VaultAdmins"
  type     = "external"
  policies = [var.admin_policy_name]
}

resource "vault_identity_group_alias" "group-alias" {
  name           = "VaultAdmins"
  mount_accessor = vault_ldap_auth_backend.ldap.accessor
  canonical_id   = vault_identity_group.vault_admins.id
}

resource "vault_policy" "admin" {
  name   = var.admin_policy_name
  policy = data.vault_policy_document.admin.hcl
}

# Wide-open starter policy for VaultAdmins
# Assuming this will be tweaked as we further refine on what specific capabilities we will need (VC-456)
data "vault_policy_document" "admin" {
  rule {
    path         = "secret/*"
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    description  = "allow all on secret"
  }
  rule {
    path         = "secrets/*"
    capabilities = ["read", "list"]
    description  = "allow all on secrets"
  }
  rule {
    path         = "mssql/*"
    capabilities = ["read", "list"]
    description  = "allow all on mssql"
  }
  rule {
    path         = "ad/*"
    capabilities = ["read", "list"]
    description  = "allow all on ad"
  }
  rule {
    path         = "tls/*"
    capabilities = ["read", "list"]
    description  = "allow all on tls"
  }
  rule {
    path         = "tls-auth/*"
    capabilities = ["read", "list"]
    description  = "allow all on tls-auth"
  }
  rule {
    path         = "sys/auth/*"
    capabilities = ["create", "update", "delete", "sudo"]
    description  = "allow Create, update, and delete auth methods"
  }
  rule {
    path         = "sys/mounts/*"
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    description  = "allow all on mounts"
  }
  rule {
    path         = "sys/leases/*"
    capabilities = ["read", "list"]
    description  = "allow all on leases"
  }
  rule {
    path         = "sys/policy"
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    description  = "allow all on policies"
  }
  rule {
    path         = "sys/policy/*"
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    description  = "allow all on policies"
  }
  rule {
    path         = "auth/*"
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    description  = "allow all on auth"
  }
  rule {
    path         = "sys/auth"
    capabilities = ["read", "list"]
    description  = "allow List auth methods"
  }
  rule {
    path         = "sys/policies/acl"
    capabilities = ["read", "list"]
    description  = "allow List existing policies"
  }
  rule {
    path         = "sys/policies/acl/*"
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    description  = "allow Create and manage ACL policies"
  }
  rule {
    path         = "sys/mounts"
    capabilities = ["read"]
    description  = "allow List existing secret engines"
  }
  rule {
    path         = "sys/health"
    capabilities = ["read", "sudo"]
    description  = "allow Read health checks"
  }
}
