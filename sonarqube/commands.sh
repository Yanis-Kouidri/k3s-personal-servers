#!/bin/bash

# Postgre database
helm upgrade --install -n sonarqube sonar-postgres bitnami/postgresql -f postgres-values.yaml

# Sonarqube 
helm upgrade --install -n sonarqube sonarqube sonarqube/sonarqube -f sonar-values.yaml


# Create a secret for Postgres password
export SOPS_AGE_KEY=$(cat age-key.txt)
sops --input-type yaml --output-type yaml -d secrets.yaml.enc > secrets.yaml
kubectl create secret generic sonarqube-postgres-secret \
  --from-literal=password=$(yq eval '.postgresql.password' secrets.yaml) \
  --namespace sonarqube
rm secrets.yaml
