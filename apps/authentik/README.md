# Authentik

Authentik is available at `https://auth.kouidri.fr` through the Envoy Gateway.

The Helm chart deploys one Authentik server, one worker, and a persistent
PostgreSQL database. Sensitive bootstrap and database values are stored in
`secrets.enc.yaml` with SOPS.

## Initial login

Flux creates the initial `akadmin` account from the encrypted bootstrap
password. Retrieve it locally with:

```bash
