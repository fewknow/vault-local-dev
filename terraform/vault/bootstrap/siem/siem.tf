resource "vault_audit" "enable_siem" {
  type = "socket"

  options = {
    address     = "${var.siem_address}:514"
    socket_type = var.siem_socket_type
    description = var.description
    prefix      = var.siem_prefix
    format      = var.siem_format
  }
}
