#QVC Vault secrets KV path

#QVC secrets path
resource "vault_mount" "secrets" {
  path = "secrets/"
  type = "generic"
}
