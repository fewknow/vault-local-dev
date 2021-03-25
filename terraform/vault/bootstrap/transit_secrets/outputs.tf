output "mount_path" {
    value = vault_mount.transit_mount.path
}

output "transit_key_name" {
    value = vault_transit_secret_backend_key.key.name
}
