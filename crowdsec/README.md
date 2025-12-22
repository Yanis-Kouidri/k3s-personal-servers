# CrowdSec

## Installation

```bash
helm repo add crowdsec https://crowdsecurity.github.io/helm-charts
helm repo update
```

```bash
kubectl create ns crowdsec
```

```bash
helm install crowdsec crowdsec/crowdsec -n crowdsec -f values.yaml
```

Reinstall with a new `values.yaml` config:

```bash
helm upgrade --install crowdsec crowdsec/crowdsec -n crowdsec -f
values.yaml
```