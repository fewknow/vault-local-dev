#Apps
This is where the application policy lives.  This is a generic policy per application to allow for automatic onboarding to vault.  This policy allows the application in interact with all the supported secrets engines.  Since all roles and policies are named for the application itself, there is a 1 to 1 mapping for each.

The code in this folder combined with the security roles repo will run together to complete the onboarding of an application with its permissions to use the secrets engines that are supported.

#Orchestrator
This process will be moved to its own repo and be used in conjunction with a renewal and creation of certificate job that will run in the background to have a single place that all certificate actions will occur.

This is the heart of the application getting its authentication set and mapped back to vault.
`vault_cert_gen.py`  will generate a client TLS certificate using the Vault PKI secrets engine.
You may need to install the `requirements.txt` with pip before you can generate a certificate.

You will then need to get a provisioner token to be able to map the certificate to the vault backend role that can be found in tls.tf

To generate a provisioner token you can run the provisioner.tf file with `terraform apply`

##NOTE
There is no backend configuration for state for any part of the orchestrator because these are all one time tasks that don't need to be tracked for state change.


#TFvars
This should be used to configure any variables that will need to change between enviroments and will be referenced in remote states across different TF files.

#Vault
This is the code to bootstrap vault with its secrets engines and auth methods.
#NOTE
This will also not have a state file associated with it.  This is to protect the secerte zeros that will be used to configure the secrets engines.  This will not only server as boostrap but will also be where code will be put and ran as featured are added to the vault installation.

#Vault-Consul
This is for the ACL's that are used for consul to be able to back vault as a backend.  This is only used during the build process to pass a token to vault using ansible.  There should also be no state file for this.

#Standalone-Consul
This is for ACL's for the consul used for applicaiton configuraion.  This will accessed mainly programatically in a pipeline using a token that has permissions.


#Backend and Configs
`set_backend.sh` - this allows you to test locally with consul backend and move to artifactory (for now) in the actual environments.
`local-backend.config` - this is used for local developement.
`west-chester.config` - each data center will needs it own configuration.
