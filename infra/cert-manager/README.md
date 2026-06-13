# Cert manager

Download gpg key (optional but safe)

    curl -LO https://cert-manager.io/public-keys/cert-manager-keyring-2021-09-20-1020CF3C033D4F35BAE1C19E1226061C665DF13E.gpg

Install with verification

```bash
    helm upgrade --install cert-manager oci://quay.io/jetstack/charts/cert-manager --namespace cert-manager \
    --set config.apiVersion="controller.config.cert-manager.io/v1alpha1" \
    --set config.kind="ControllerConfiguration" \
    --set config.enableGatewayAPI=true
```

Update:

```bash
    helm upgrade cert-manager --reset-then-reuse-values --version <version> oci://quay.io/jetstack/charts/cert-manager
```



