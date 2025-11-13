# Setup longhorn

Install it

```bash
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.10.1/deploy/longhorn.yaml
```

Port forward

```bash
kubectl port-forward svc/longhorn-frontend 8080:80 -n longhorn-system &
```

Setup a tunnel from the local PC (not the VPS)

```bash
ssh myvps -L 8080:localhost:8080
```

Access to http://localhost:8080