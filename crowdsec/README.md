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
helm upgrade --install crowdsec crowdsec/crowdsec -n crowdsec -f values.yaml
```

## Bouncer component

check if iptables or nftables is used

```bash
iptables -V
```

Install repo:

```bash
curl -s https://install.crowdsec.net | sudo sh
```

### If nftables

```bash
sudo apt install crowdsec-firewall-bouncer-nftables
```

### If iptables

```bash
sudo apt install crowdsec-firewall-bouncer-iptables
```

Generate a API key en LAPI:

```bash
kubectl exec -n crowdsec deployment/crowdsec-lapi -- cscli bouncers add vps-host-bouncer
```

Edit this file:

```bash
sudo vi /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml
```

change :

```yaml
api_url: http://<SERVICE_CLUSTER_IP>:8080/
api_key: <API_KEY>
```

Restart:

```bash
sudo systemctl restart crowdsec-firewall-bouncer
```

Check:

```bash
kubectl exec -n crowdsec <POD_LAPI> -- cscli bouncers list
```

## Debug

To see decision tooken by LAPI

```bash
kubectl exec deployment/crowdsec-lapi -n crowdsec -- cscli decisions list
```

To see metrics

```bash
kubectl exec daemonsets/crowdsec-agent -n crowdsec -- cscli metrics
```

To see aquisition files (`aquis.yaml`)

```bash
kubectl exec daemonsets/crowdsec-agent -n crowdsec -- cat /etc/crowdsec/acquis.yaml
```