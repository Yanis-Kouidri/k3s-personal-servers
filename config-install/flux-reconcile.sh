#!/bin/bash

flux reconcile kustomization envoy --with-source
flux reconcile kustomization cert-manager --with-source
flux reconcile kustomization flux-system --with-source
flux reconcile kustomization infra --with-source
flux reconcile kustomization apps --with-source
