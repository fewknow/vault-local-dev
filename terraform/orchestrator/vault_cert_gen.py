""" Generate Certs from Vault """
import json
import argparse
import requests

# initiate the parser allowing you to pass in parameters to the script and
# having -h to see the avaible parameters.
PARSER = argparse.ArgumentParser()
PARSER.add_argument("-T", "--token", help="provisioner token for vault PKI certs")
PARSER.add_argument("-U", "--url", help="Vault URL")
PARSER.add_argument("-C", "--commonname", help="Common name for application")
PARSER.add_argument("-TTL", "--ttl", help="TTL for cert. Defaults to 168h")

ARGS = PARSER.parse_args()

# validation of required paramters
if ARGS.token is None:
    raise ValueError("Must provider provisioner token")
if ARGS.url is None:
    raise ValueError("Must provider Vault URL")
if ARGS.commonname is None:
    raise ValueError("Must provide common name")
if ARGS.ttl is None:
    ARGS.ttl = "168h"

# This is the call to the vault pki secrets engine that will generate a
# tls certificate to later be used for vault client tls auth.   This cert also
# has the common name passed to it so that it can only be used by the
# sepcific application it was created for during authentication.

HEADERS = {
    'Cache-Control' : 'no-cache',
    'Content-Type' : 'application/json',
    'X-Vault-Token' : ARGS.token
}
URL = "{u}/v1/tls-auth/issue/tls-auth-issuer-role".format(u=ARGS.url)
DATA = {
    "common_name" : ARGS.commonname,
    "ttl" : ARGS.ttl
}
RESPONSE = requests.post(URL, headers=HEADERS, data=json.dumps(DATA), verify=False)


# parseing the response to write out to separate files.

JSON = json.loads(RESPONSE.text)

CERT = JSON['data']['certificate']

CA = JSON['data']['issuing_ca']

PRIVATE = JSON['data']['private_key']

# spliting out the separate certs from response.
CERT_ARRAY = CERT.splitlines()
CA_ARRAY = CA.splitlines()
PRIVATE_ARRAY = PRIVATE.splitlines()


# writing out the certificates thtat were returned from the pki engine.
with open('cert.crt', 'a') as the_cert_file:
    for line in CERT_ARRAY:
        the_cert_file.write(line + "\n")

with open('ca-cert.pem', 'a') as the_ca_file:
    for line in CA_ARRAY:
        the_ca_file.write(line + "\n")

with open('private.crt', 'a') as the_private_file:
    for line in PRIVATE_ARRAY:
        the_private_file.write(line + "\n")
