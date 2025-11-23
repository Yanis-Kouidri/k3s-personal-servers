# SonarQube Community

## Prerequies

HTTPRoute CRD must be install

## Install helm repo

    helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
    helm repo update

## Decrypt and apply secret


##  Install or upgrade Postgres database

    helm upgrade --install --create-namespace -n sonarqube postgres-sonarqube oci://registry-1.docker.io/bitnamicharts/postgresql -f postgres-values.yaml

# Install or upgrade Sonarqube 

    helm upgrade --install --create-namespace -n sonarqube sonarqube sonarqube/sonarqube -f sonar-values.yaml

It may be necessary to go en sonarqube.kouidri.fr/setup to upgrade database after upgrade
