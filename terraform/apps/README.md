# Terraform Application Policy

The scripts in this directory are in charge of taking an JSON document as input and transforming it into Vault HCL policies

## Schemas

Schemas are translated to a Terraform map through the policy-template file

### 1.0
#### JSON Document

    {
        "_schemaversion" : "1.0",
        "policies" : [
            {
                "datacenter": "dc1",
                "environment": "envdev",
                "services": [
                    {
                        "name": "application-portfolio-management",
                        "certificate-common-names":[
                            "fewknow.net",
                        ],
                        "database":[
                            "databse"
                        ]
                    }
                ]
            }
        ]
    }

#### Terraform Map
    [
        {
            "_schemaversion":"string",
            "datacenter":"string",
            "environment":"string",
            "name":"string",
            "certificate_common_names":"string[]",
            "active_directory":"string[]",
            "database":"string[]"
        }
    ]

## Datacenters
Each policy object in the JSON input will specify a datacenter and an environment. The datacenters file uses a combination of those two variables and will map to the appropriate Vault instance if it exists. 

## Outputs
