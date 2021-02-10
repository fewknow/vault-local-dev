FROM centos:latest

# Set variables 
ENV ENT_VAULT_VERSION=1.6.0

# Install deps 
RUN dnf -y install epel-release && dnf -y update 
RUN dnf -y install curl jq unzip vim awscli

# Make project directories 
RUN mkdir -p /etc/vault.d/data \
&& mkdir -p /etc/certs

# Copy over the vault config file 
COPY ./config/ent-vault.hcl /etc/vault.d/vault.hcl

# Download Vault 
RUN curl --output vault_${ENT_VAULT_VERSION}.zip https://releases.hashicorp.com/vault/${ENT_VAULT_VERSION}+ent/vault_${ENT_VAULT_VERSION}+ent_linux_amd64.zip

# Install Vault 
RUN unzip vault_${ENT_VAULT_VERSION}.zip \
&& chown root:root vault \
&& mv vault /usr/local/bin 

# Install Vault Auto-complete
RUN vault -autocomplete-install \
&& bash -c 'complete -C /usr/local/bin/vault vault'

# Expose the Vault API port 
EXPOSE 8200/tcp 

# Create a startup script
RUN echo "/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl" > startup.sh

CMD [ "bash", "startup.sh" ]