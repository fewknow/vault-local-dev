"test" = {
    {
      "_schemaversion"           = local.json_data["${collection_key}"]._schemaversion
      "datacenter"               = policy_collection.datacenter
      "environment"              = policy_collection.environment
      "name"                     = service.name
      "certificate_common_names" = try(service.certificate-common-names, [])
      "active_directory"         = try(service.active-directory, [])
      "database"                 = try(service.database, [])
    }
}