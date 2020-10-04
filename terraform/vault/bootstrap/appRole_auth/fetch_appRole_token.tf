# Per the design and best practice the AppRole ID and Secret ID should never be kept together. 
# Even better, the appRole ID's should never leave Vault until the application auth process. 
# To Facilitate that security, we generate a one-time use, limited time token which has access to get the,
# role_id and secret_id for a sepcific application.

resource "vault_token" "fetch_approle" {
  display_name = "AppRole-Fetch-Token"
  no_parent    = true
  policies     = ["approle-fetch-policy"]
  ttl          = "730h" # 1 month - is in, app must deploy monthly to be renewable
  num_uses     = 3 # 1 to get role-id, and one to get secret-id, and 1 to renew itself
}