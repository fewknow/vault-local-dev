#Vault secrets KV path
resource "vault_mount" "secrets" {
  path = "secrets/"
  type = "generic"
}
