# SonarQube Community

## Prerequisites

- HTTPRoute CRD must be installed
- The secret `sonarqube-postgres-secret` must exist in the `sonarqube` namespace (created manually from `secrets.enc.yaml`)

## FluxCD Management

SonarQube and its PostgreSQL database are now managed by **FluxCD**.

### Automatic upgrade workflow

1. **Renovate** updates `buildNumber: "26.6.0.123539"` in `sonar-values.yaml` when a new SonarQube version is released
2. Flux detects the change in the Git repository
3. Kustomize regenerates the `sonarqube-values` ConfigMap from the updated `sonar-values.yaml`
4. The `HelmRelease` detects the ConfigMap change and triggers a Helm upgrade to the latest chart version
5. SonarQube is upgraded automatically

> **Note:** It may be necessary to visit `https://sonarqube.kouidri.fr/setup` to run database migrations after an upgrade.

### Manual approach (alternative)

If you need to manage SonarQube manually without Flux:

```bash
# Install PostgreSQL
helm upgrade --install --create-namespace -n sonarqube postgres-sonarqube oci://registry-1.docker.io/bitnamicharts/postgresql -f postgres-values.yaml

# Install SonarQube
helm upgrade --install --create-namespace -n sonarqube sonarqube sonarqube/sonarqube -f sonar-values.yaml
```

### Secrets

The secret `sonarqube-postgres-secret` is encrypted with SOPS (`secrets.enc.yaml`). To create/update it:

```bash
sops --decrypt secrets.enc.yaml | kubectl apply -f -
```

### Database backup

```bash
crontab -e
```

Add this line:

```bash
0 3 * * * /home/ubuntu/k3s-personal-servers/apps/sonarqube/backup.sh >> /home/ubuntu/backups/sonarqube/backup-sonarqube.log 2>&1