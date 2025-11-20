#!/bin/bash
# DO NOT RUN THIS SCRIPT, JUST COPY PASTE COMMAND AND ADAPT THEM

# Install or upgrade Postgres database
helm upgrade --install --create-namespace -n sonarqube sonar-postgres bitnami/postgresql -f postgres-values.yaml

# Install or upgrade Sonarqube 
helm upgrade --install --create-namespace -n sonarqube sonarqube sonarqube/sonarqube -f sonar-values.yaml

# It may be necessary to go en sonarqube.kouidri.fr/setup to upgrade database after upgrade


# Setting up Secret:

# To encrypt:

export PUBLIC_AGE_KEY=age1XXXXXXXX # Paste the public key here
sops --encrypt --age $PUBLIC_AGE_KEY secrets.yaml > secrets.enc.yaml


# To decrypt and apply

read -s -p "Fill the private Age key: " SOPS_AGE_KEY && export SOPS_AGE_KEY && echo  # Paste the secret age key here
sops --input-type yaml --output-type yaml -d secrets.enc.yaml | kubectl apply -f -

# To decrypt
sops --input-type yaml --output-type yaml -d secrets.enc.yaml > secrets.yaml