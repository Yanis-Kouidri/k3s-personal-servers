#!/bin/bash

# Install or upgrade Postgres database
helm upgrade --install --create-namespace -n sonarqube sonar-postgres bitnami/postgresql -f postgres-values.yaml

# Install or upgrade Sonarqube 
helm upgrade --install --create-namespace -n sonarqube sonarqube sonarqube/sonarqube -f sonar-values.yaml

# It may be necessary to go en sonarqube.kouidri.fr/setup to upgrade database after upgrade

# To encrypt:

sops --encrypt --age <PUBLIC_KEY_IN_TXT_FILE> secrets.yaml > secrets.enc.yaml


# To decrypt and apply

export SOPS_AGE_KEY=$(cat age-key.txt)
sops --input-type yaml --output-type yaml -d secrets.yaml.enc | kubectl apply -f -
