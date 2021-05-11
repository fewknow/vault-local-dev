# Vault Local Development
A docker-compose drive project for local Vault development. This will run Vault backed by Consul, and Mssql in a docker-compose cluster behind TLS certs. Terraform is used to bootstrap the vault configuration. 

There are 2 options to run this project, the Quick_start will prompt you for your project name and will configure everything for you behind the scenes; the manual option will allow you to walk through the process of the docker config then the TF project to configure it all. 

***This project is a work in-progress, Sam Flint and Ian Copeland would love any suggestions you might have in the form of a PR.***

---
### Pre-reqs
- awscli
- vault
- terraform
- docker

Before running this project you will need to be logged into the DoU Training AWS account for access to the Enterprise Vault license as well as the KMS key.

### Quick Start option:
From the project root run the `sh scripts/quick_start.sh` script to build your cluster. You will be promepted to name your project unless certs are found in the config directory; in which case the script will use the name of your pem file for the project name. This will complete the following tasks: 

1.Create self signed TLS certs for Vault/Consul 
2.Run a docker compose project with Vault
  * Enterprise will build a custom docker image using RAFT as a storage backend
  * Entperise will also start a KMIP server in a docker container 
  * Enterprise uses AWSKMS for autounseal
  * OSS uses offical hashi image with consul as a backend
3. Docker starts a Mssql container for a demo of dyanmic secrets 
4. Script inits Vault and recovery stores keys in /_data/keys.txt
5. Optional: Bootstrap Vault via TF with all or some of the following:
  * Create ACL provisioner policy
  * Create kv secret mount
  * Create TLS auth mount and role
  * Create root and intermediate PKI Engine 
  * Create AppRole 
  * Create mssql secret mount and role 
 6. If you bootstrapped TLS/PKI/MSSQL/ACL Provisioner, you have the option to run the app onboard/read mssql via dynamic creds demo. 
 7. The same demo as above, but using approle auth rather than TLS

### Manual Start:
1. First you will need to generate the certs.   Run `bash create_local_certs.sh <name>` from the project root. 
2. Now you will need to add the `localhost.crt` to you keychain on your machine
set it to `trust always`
3. Now copy `localhost.key` and `localhost.crt` to ./config - this will allow
vault to stand up with TLS.

Now you will need to run `docker-compose up`.  This should give you vault backed by
consul plus, consul as a backend for your terraform code.

From here you will need to unseal vault. Run `bash unseal.sh`.  This will unseal vault and produce a file at
`local-vault-dev/_data/keys.txt` that will container the unseal keys and the root token.

## Configure Terraform to run plans and apply.
First you will need to set the $VAULT_ADDR to the vault address you want to run your terraform against.  
>export VAULT_ADDR=https://localhost:8200
> https://localhost:8200 for local testing

Then add the root token for terraform to default to when running bootstrap.
> export VAULT_TOKEN=<root token from `_data`>

You will need to initialize Terraform using the config file backend per environment (LOCAL, artifactory)
Navigate to terraform/ and run the `set_backend.sh true` for local testing or just `set_backend.sh` for artifactory.

## BootStrap
You should see a bash script that will handle bootstrap in local-vault-dev/. You will need to supply this script with a token and ip or DNS address of the MSSQL server.  For local you will need to use your own IP.
For this you need your root token and local IP address, the root token is inside `_data/keys.txt_` and you can get your local IP address with `ifconfig | awk '/broadcast/{print $2}'` then run:
`bash bootstrap_vault.sh <root token> <local IP address>`
> bash bootstrap_vault.sh <root-token> <ip>

##Policy and role setup
Now you need to set up applications `app.sh <root token>` if successful this will show you the app-roles tokens.
> bash app.sh <root-token>

#Orchestrator - for trusted introduction
You will need to navigate to terraform/orchestrator.  Here you will have a script that is used to generate client TLS certifactes for authentication. `python parse_certs.py -T <root token> -U <Vault URL> -C <URL common name>` if successful you should get a response with GPG keys and OK 200.
Now you can navigate to `orchestrator/provisioner` and run `terraform init` `terraform apply`.  This will produce a token that will allow you to create a
backend auth role for vault and map the new cert to it.  navigate back to `orchestrator/tls`, set your VAULT_TOKEN=<new token you just go> then then `terraform init` `terraform apply`.  Neither of these will be stored in the state file for terraform for security reasons.
Now you should have completed:
  - Creates a certificate.
  - Puts the certificate in Vault.
  - Maps the certificate to the PKI role (that role is mapped to a policy) and gives the cert to an application so when the application authenticates it gets a token which is mapped to that policy.

#Confirming
`cd` to the `terraform/orchestrator`, make sure all the certificates we've just generated are there and create a token, run `vault login -method=cert -client-cert=cert.crt -client-key=private.crt name=ilc` this will be mapped to the `ilc-policy`.

To generate your new set of credentials use
    Ex:
    ```
    $ vault read mssql/creds/ilc-role
    Key                Value
    ---                -----
    lease_id           mssql/creds/readonly/IQKUMCTg3M5QTRZ0abmLKjTX
    lease_duration     1h
    lease_renewable    true
    password           A1a-T7Ezuy261IBew8H9
    username           v-token-readonly-47vOtpF7pZq79Xajx7yq-1556567237
    ```
To generate a token use
    Ex:
    ```
    $ vault token create -policy="ilc-policy"
    Key                  Value
    ---                  -----
    token                s.bdC5uj32O2qiBvEesBjtw7CW
    token_accessor       Yvbe7cAAjuG1ve0LAiawJJlS
    token_duration       768h
    token_renewable      true
    token_policies       ["default" "ilc-policy"]
    identity_policies    []
    policies             ["default" "ilc-policy"]
    ```

---

Note: If you're using a Linux machine the first step is to give `rwxrwxrwx` permissions recursively to the `data` and `config` folders as Docker is unable to access them on a Linux machine without those permissions. The problem is not present on MacOS. Run `chmod -R 777 _data config`.

Note: On MacOS you need to install `gnu-sed` to be able to run the `token_replacer` script, this is required because the version of `sed` bundbled with MacOS is different to the one that comes with Linux systems, this is documented [here](https://unix.stackexchange.com/questions/13711/differences-between-sed-on-mac-osx-and-other-standard-sed).

Install GNU sed on MacOS: `$ brew install gnu-sed`
