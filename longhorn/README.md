# Longhorn

## Install

Add repo:

```bash
helm repo add longhorn https://charts.longhorn.io
helm repo update
```

Install (*look for the latest version on [GitHub](https://github.com/longhorn/longhorn)*):

```bash
helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace --version VERSION
```

## Access UI

Port forward:

```bash
kubectl port-forward svc/longhorn-frontend 8080:80 -n longhorn-system > /dev/null 2>&1 &
```

Setup a tunnel from the local PC (not the VPS):

```bash
ssh ovh-vps -NL 8080:localhost:8080
```

Access from client to [http://localhost:8080](http://localhost:8080).

**To kill port forward:**

Find the pid with:

```bash
jobs -l
```

or

```bash
ss -plantu | grep 8080
```

Then kill with:

```bash
kill -9 PID
```

## Set replicas count to 1

If longhorn is installed on a mono-node kubernetes cluster, longhorn won't be able to create replicas so it is better to set default value to 1.

Go on UI -> Setting tabs -> Default Replica Count -> 1

Restart:
```bash
    kubectl rollout restart deployment minecraft-server -n minecraft
```
