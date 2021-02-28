output "mount_path" {
    value = vault_mount.transform_mount.path
}

output "transform_role" {
    value = vault_transform_role.payments_role.name
}

output "transformation_created" {
    value = vault_transform_transformation.ccn_transform.name
}