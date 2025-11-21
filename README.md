# Secrets with SOPS and age

This project uses [SOPS](https://github.com/getsops/sops) and [age](https://github.com/FiloSottile/age) to manage Kubernetes secrets.

## Prerequisites

- `sops` installed
- `age` key pair generated
- `kubectl` configured for the target cluster

## Set up public key

    export PUBLIC_AGE_KEY=age1XXXXXXXX # Paste your age public key here

## Encrypt secrets

    sops --encrypt --age "$PUBLIC_AGE_KEY" secrets.yaml > secrets.enc.yaml

## Decrypt and apply to Kubernetes

    read -s -p "Fill the private Age key: " SOPS_AGE_KEY && export SOPS_AGE_KEY && echo
    sops --input-type yaml --output-type yaml -d secrets.enc.yaml | kubectl apply -f -

## Decrypt to a file

    sops --input-type yaml --output-type yaml -d secrets.enc.yaml > secrets.yaml
