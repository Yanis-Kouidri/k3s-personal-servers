#!/bin/bash
# DO NOT RUN THIS SCRIPT, JUST COPY PASTE COMMAND AND ADAPT THEM

# Install or upgrade Postgres database
helm upgrade --install --create-namespace -n sonarqube sonar-postgres bitnami/postgresql -f postgres-values.yaml

# Install or upgrade Sonarqube 
helm upgrade --install --create-namespace -n sonarqube sonarqube sonarqube/sonarqube -f sonar-values.yaml

# It may be necessary to go en sonarqube.kouidri.fr/setup to upgrade database after upgrade
