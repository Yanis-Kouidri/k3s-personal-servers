# FluxCD

To update fluxCD CLI:

```bash
curl -s https://fluxcd.io/install.sh | sudo bash
```

To update fluxCD deployment:

```bash
flux bootstrap github   --owner=$GITHUB_USER   --repository=k3s-personal-servers   --branch=main   --path=./clusters/my-cluster   --personal
```

To check everything is fine:

```bash
flux check
```
