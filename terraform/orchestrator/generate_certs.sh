




# #generate tls cert  USE PYTHON SCRIPT PROVIDED CALLED parse_certs.py
# curl --header "X-Vault-Token:  s.NXcwAthrRL6NwpSCGva40c2k" --request POST \
#     --data '{ "common_name" : "localhost", "ttl" : "24h" }' https://localhost:8200/v1/pki/issue/ilc-pki-role
#

###NEED TO CREATE TLS AUTH FROM THESE CERTS
### Run terraform in the tls directory

#login with tls cert
export VAULT_SKIP_VERIFY=true
vault login -method=cert -client-cert=cert.crt -client-key=private.crt name=ilc



### NOW TRY TO GET DATABASE CREDS
## STILL NEED TO COMPLETE THIS.
export VAULT_TOKEN=s.ecNN96aB0Zy3VJhF9n4pnkaj
vault read mssql/creds/ilc-pki-role
