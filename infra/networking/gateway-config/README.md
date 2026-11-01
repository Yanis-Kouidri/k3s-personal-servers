# Gateway configuration

Envoy Gateway itself (the controller) is installed by Flux from
`infra/networking/envoy-gateway/`, as a HelmRelease of the `gateway-helm` OCI
chart (version pinned in `oci-repository.yaml`, bumped by Renovate). It is applied
by the `envoy` Flux Kustomization (`clusters/my-cluster/envoy.yaml`).

This folder holds what runs on top of it, applied by the `infra` Kustomization:

- `gateway.yaml`: the dual-stack `EnvoyProxy`, the `envoy-gateway`
  GatewayClass and Gateway (HTTP and HTTPS listeners), the HTTP to HTTPS redirect
  and the `kouidri.me` redirect
- `certificates.yaml`: the `kouidri-fr-tls` certificate used by the HTTPS
  listener. Stalwart has its own, issued in its namespace
  (`apps/mail/stalwart/certificate.yaml`)
- `client-traffic-policy.yaml`: response headers added to every response
- `backend-traffic-policy.yaml`: PROXY protocol towards Stalwart

The onion service of the personal website lives in its own namespace, see
`infra/tor/`.

## Check

```bash
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
kubectl get gateway -n envoy-gateway-system
```
