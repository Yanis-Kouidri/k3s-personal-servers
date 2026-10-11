# Cert manager

Managed by Flux, nothing to install by hand.

- `controller/`: the cert-manager HelmRelease (chart pinned in `helm-release.yaml`,
  bumped by Renovate) with the Gateway API integration enabled
  (`enableGatewayAPI: true`), and its NetworkPolicies. Applied by the
  `cert-manager` Flux Kustomization (`clusters/my-cluster/cert-manager.yaml`).
- `config/`: the `letsencrypt-prod` and `letsencrypt-staging` ClusterIssuers,
  which solve HTTP-01 through the `envoy-gateway` Gateway. Applied by the `infra`
  Flux Kustomization, which depends on `cert-manager`.

The certificate itself (`kouidri-fr-tls`) is declared in
`infra/networking/gateway-config/certificates.yaml`.

## Check

```bash
flux get helmreleases -n cert-manager
kubectl get clusterissuers
kubectl get certificates -A
```
