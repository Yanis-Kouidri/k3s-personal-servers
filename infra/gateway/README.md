# Envoy Api Gateway

## Install

NB: Check if newest version exist

    helm install envoy-gateway oci://docker.io/envoyproxy/gateway-helm --version v1.6.0 -n envoy-gateway-system --create-namespace

## Check

    kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
