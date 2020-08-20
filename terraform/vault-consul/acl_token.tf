## ACL Tokens
resource "consul_acl_token" "vault" {
  description = "vault_token"
  policies    = ["${consul_acl_policy.agents.name}"]
  local       = true
}

resource "consul_acl_token" "keys" {
  description = "acl_token_to_write_keyvalues"
  policies    = ["${consul_acl_policy.kv_write.name}"]
  local       = true
}

resource "consul_acl_token" "ui_write" {
  description = "UI_acl_token_to_write_keyvalues"
  policies    = ["${consul_acl_policy.kv_write.name}"]
  local       = true
}

resource "consul_acl_token" "backup" {
  description = "consul_backup_token"
  policies    = ["${consul_acl_policy.snapshot.name}"]
  local       = true
}
