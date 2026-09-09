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

Generate a API key on LAPI:

```bash
kubectl exec -n crowdsec deployment/crowdsec-lapi -- cscli bouncers add vps-host-bouncer
```

Edit this file:

```bash
sudoedit /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml
```

change :

```yaml
api_url: http://<CROWDSEC_SERVICE_CLUSTER_IP>:8080/
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

## Agent registration

The upstream chart's `wait-for-lapi-and-register` init container runs `cscli lapi register`
on **every** pod start, with the pod name as the machine name. LAPI keeps its machines in a
persistent volume, so a pod that is *restarted* instead of *recreated* (node reboot, kubelet
restart) tries to register a name that already exists and gets:

```
Error: cscli lapi register: api register (http://crowdsec-service.crowdsec:8080/) http 403 Forbidden:
API error: user 'crowdsec-agent-xxxxx': user already exist
```

The init container then crash-loops forever and the agent never starts, which silently
disables CrowdSec on the node. The `postRenderers` block in `helmrelease.yaml` patches the
command so it registers only when the agent has no credentials yet.

Each *recreated* pod still registers under a new name, so dead machines accumulate in LAPI.
List and clean them up with:

```bash
kubectl exec -n crowdsec deployment/crowdsec-lapi -- cscli machines list
kubectl exec -n crowdsec deployment/crowdsec-lapi -- cscli machines prune --duration 24h
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
