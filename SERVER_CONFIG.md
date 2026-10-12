# Steps to config the server

> Tested on Ubuntu 26.04 on June 2026

## SSH

During the VPS provisioning on OVH (or other), provide a brand new ED25519 ssh public key to be able to connect to the VPS directly via SSH. If it's not possible, check host fingerprint, connect to the VPS with password and add manually SSH key as explained here:

Get the ssh fingerprint on server (via web interface for example):

```bash
ssh-keygen -l -f /etc/ssh/ssh_host_ed25519_key.pub
```

SSH the server with password and add your client public key on `authorized_keys` file.

Check if it works.

If yes, copy the file `config-install/99-security-hardening.conf` into `/etc/ssh/sshd_config.d/99-security-hardening.conf`

```bash
sudo cp config-install/99-security-hardening.conf /etc/ssh/sshd_config.d/99-security-hardening.conf
```

**Check:**

```bash
sudo sshd -t
```

**Restart:**

```bash
sudo systemctl restart ssh
```

On client side save the config on `.ssh/config`. Adapt user, port, IP ADDRESS and identityfile (private key).

```ssh
Host my-vps
    HostName <IP_ADDRESS>
    User ubuntu
    Port 22
    IdentityFile ~/.ssh/id_ed25519_vps
```

## Shell

Set a good host name:

```bash
sudo hostnamectl set-hostname vps-ovh-prod
```

Set a good time zone:

```bash
sudo timedatectl set-timezone Europe/Paris
```

Install dotfiles: [https://github.com/Yanis-Kouidri/dotfiles](https://github.com/Yanis-Kouidri/dotfiles)

Set a good shell:

```bash
curl -sS https://starship.rs/install.sh | sh
```

Then:

```bash
echo 'eval "$(starship init bash)"' >> ~/.bashrc
```

Apply the config:

```bash
mkdir ~/.config/
cp config-install/starship.toml ~/.config/starship.toml
```

## Install K3s

Update system and disable firewall:

```bash
sudo apt update && sudo apt upgrade -y
sudo ufw disable
```

Setup k3s config file:

```bash
sudo mkdir -p /etc/rancher/k3s/
sudo cp config-install/config.yaml /etc/rancher/k3s/config.yaml
# referenced by config.yaml (kubelet-arg), must be present before k3s starts
sudo cp config-install/kubelet-config.yaml /etc/rancher/k3s/kubelet-config.yaml
```

Install k3s:

```bash
curl -sfL https://get.k3s.io | sh -
```

Configure kubeconfig:

```bash
unset KUBECONFIG

mkdir -p "$HOME/.kube"
sudo install -o "$USER" -g "$USER" -m 0600 \
  /etc/rancher/k3s/k3s.yaml \
  "$HOME/.kube/config"

export KUBECONFIG="$HOME/.kube/config"
echo 'export KUBECONFIG="$HOME/.kube/config"' >> ~/.bashrc
```

Check status and nodes:

```bash
sudo systemctl status k3s
kubectl get nodes
```

## Secrets encryption at rest

`config.yaml` sets `secrets-encryption: true`, so a fresh install encrypts Secret
objects in the datastore (`/var/lib/rancher/k3s/server/db/state.db`) from the start.

The key lives in `/var/lib/rancher/k3s/server/cred/encryption-config.json`, next to
the database: this protects a copy of `state.db` on its own (a leaked snapshot or
backup), not someone who is root on the node or can `get secrets` through the API.

On a node installed before this setting, enable it and re-encrypt what is already
stored (each restart makes the API unavailable for a few seconds, pods keep running):

```bash
sudo k3s secrets-encrypt enable
sudo systemctl restart k3s
sudo k3s secrets-encrypt reencrypt
sudo systemctl restart k3s
```

Check (expected: `Encryption Status: Enabled` and `Current Rotation Stage: reencrypt_finished`):

```bash
sudo k3s secrets-encrypt status
```

Rotate the key later with `sudo k3s secrets-encrypt rotate-keys`, then restart k3s.

## Kubens

To easly change namespace

```bash
sudo apt install kubectx
```

## Helm

Check the [docs](https://helm.sh/docs/intro/install#from-apt-debianubuntu) if required

```bash
HELM_BUILDKITE_APT_KEY_ID="DDF78C3E6EBB2D2CC223C95C62BA89D07698DBC6"

sudo apt-get install curl gpg apt-transport-https --yes

curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey > "${TMPDIR:-/tmp}/helm.gpg"

# Ensure that the key ID matches to prevent a repository compromise from establishing an attacker controlled key
if [ "$(gpg --show-keys --with-colons "${TMPDIR:-/tmp}/helm.gpg" | awk -F: '$1 == "fpr" {print $10}' | head -n 1)" != "${HELM_BUILDKITE_APT_KEY_ID}" ]; then echo "ERROR: Unexpected Helm APT key ID: potential key compromise"; exit 1; fi

cat "${TMPDIR:-/tmp}/helm.gpg" | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

sudo apt-get update
sudo apt-get install helm
```

## FluxCD

Install the CLI:

```bash
curl -s https://fluxcd.io/install.sh | sudo bash
```

check:

```bash
flux --version
```

## Secrets with SOPS and age

This project uses [SOPS](https://github.com/getsops/sops) and [age](https://github.com/FiloSottile/age) to manage Kubernetes secrets.

### Prerequisites

- `sops` installed: [Here](https://github.com/getsops/sops/releases)
- `age` key pair generated
- `kubectl` configured for the target cluster

### Bootstrap for FluxCD

Enter private Age Key:

```bash
read -s -p "Fill the private Age key: " SOPS_AGE_KEY && export SOPS_AGE_KEY && echo
```

Create a secret:

```bash
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-literal=age.agekey="$SOPS_AGE_KEY"
```

### Set up public key

```bash
export PUBLIC_AGE_KEY=age1XXX # Paste your age public key here
```

### Encrypt secrets

With public key in `.sops.yaml`, the following command will output en encrypted version of the plain text `secrets.enc.yaml`
```bash
sops --encrypt secrets.enc.yaml
```

If you want to specify the key and create a file.

```bash
sops --encrypt --age "$PUBLIC_AGE_KEY" secrets.yaml > secrets.enc.yaml
```

### Decrypt and apply to Kubernetes (obsolete, FluxCD handles it)

Securly set private key

```bash
read -s -p "Fill the private Age key: " SOPS_AGE_KEY && export SOPS_AGE_KEY && echo
```

```bash    
sops --input-type yaml --output-type yaml -d secrets.enc.yaml | kubectl apply -f -
```
### Decrypt to a file

```bash
sops --input-type yaml --output-type yaml -d secrets.enc.yaml > secrets.yaml
```

### Decrypt to a test (in the terminal)

```bash
sops --input-type yaml --output-type yaml -d secrets.enc.yaml
```

## Back up

See `docs/backups/README.md` for what is backed up, how to check a backup is
actually restorable (`scripts/verify-restore.sh`), and the restore procedure --
including the traps that only show up when you try it.

The host side of the backups is a crontab: install `backups/crontab.bak` with
`crontab backups/crontab.bak` (create the log directories it writes to first,
cron fails silently otherwise), and `backups/k8s-backups` into
`/etc/logrotate.d/`. `backups/README.md` explains how to pull the archives to
another machine.

## Host tuning

Each file carries its own explanation in its header.

```bash
# journald capped at 1G
sudo install -D -m 0644 config-install/99-journald-size.conf /etc/systemd/journald.conf.d/99-journald-size.conf
sudo systemctl restart systemd-journald

# inotify limits, TCP BBR
sudo cp config-install/tcp-bbr.conf /etc/modules-load.d/tcp-bbr.conf
sudo modprobe tcp_bbr
sudo cp config-install/99-sysctl-tuning.conf /etc/sysctl.d/99-sysctl-tuning.conf
sudo sysctl --system

# fq qdisc on ens3, paired with BBR (applied at next boot)
sudo install -D -m 0644 config-install/10-netplan-ens3-fq.conf /etc/systemd/network/10-netplan-ens3.network.d/fq.conf
sudo tc qdisc replace dev ens3 root fq
```

## Firewall

Do not use `ufw`: it rewrites the same netfilter chains as k3s and the two end
up fighting. The host firewall is a dedicated nftables table instead,
`config-install/host-firewall.nft`, which only filters traffic arriving on
`ens3` and leaves the cluster's own chains alone.

Publicly open ports (anything else arriving on `ens3` is dropped):

- TCP 22 (SSH), 80 and 443 (Envoy Gateway), 25, 465, 587 and 993 (Stalwart mail),
  25565 (Minecraft)
- UDP 51820 (WireGuard)

Install it with an automatic rollback, in case it locks you out:

```bash
config-install/install-host-firewall.sh            # loads the rules, rollback in 180s
# from ANOTHER machine: open a new ssh session and check the public services
config-install/install-host-firewall.sh --confirm  # keep them, enable at boot
```

The current ssh session survives the load, so it proves nothing: test with a new
one. Doing nothing is enough to roll back. Remove it with `--uninstall`.

The provider's network firewall (OVH, Hetzner, ...) can be used on top, with the
same port list.

## DNS

cloud-init provisions a single resolver on `ens3` (OVH's `213.186.33.99`). When it
gets flaky, pod sandbox creation fails (`lookup auth.docker.io: Try again`) and Flux
loses its Git remote (`lookup github.com ... server misbehaving`).

`FallbackDNS=` in `resolved.conf` does **not** help: systemd-resolved only consults it
when no DNS server is known at all, and netplan defines one on the link. Failover needs
several servers on the same link.

Copy `config-install/99-dns-resilience.yaml` to `/etc/netplan/`, then:

```bash
sudo chmod 600 /etc/netplan/99-dns-resilience.yaml
sudo netplan generate
sudo networkctl reload
```

Prefer `networkctl reload` over `netplan apply` on a remote VPS: it reloads the config
without tearing the interface down.

CoreDNS reads `/etc/resolv.conf` once at startup, so it keeps forwarding to the old
list until restarted:

```bash
kubectl rollout restart deployment/coredns -n kube-system
```

Check both paths:

```bash
resolvectl status ens3 | grep 'DNS Servers'   # host and containerd
dig +short @10.43.0.10 github.com A           # cluster, through CoreDNS
```

## IPv6

IPv6 is handled by default by k3s with the `config.yaml` file

Test from another machine, it should test both 80 and 443 thanks to redirection

```bash
curl -6 -v -L http://www.kouidri.fr
```

To be sure:

```bash
curl -6 -v -L https://www.kouidri.fr
```

## k3s update

Simply run:

```
curl -sfL https://get.k3s.io | sh -s -
```

## k3s monitoring

Inspect logs:

```
journalctl -u k3s.service -f
```
