# Steps to config the server

> Tested on Ubuntu 24.04 on November 2025

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

Look on `./backups/` folder to save all local data on a remote computer.

Look for `backup.sh` files over differents servicies to locally save data

## Firewall

Do not use `ufw` or over firewall on the vps itselt, it may collaps with `k3s`.

Instead use the host firewall (OVH, Hetzner, etc.) and allow only requiered port.

Exemple with this priority : 
1. Allow TCP destination port 22, 80, 443, 25565, 51820
2. Allow TCP established to be able to reach internet
3. Allow UDP source port 53 and 123 to get UDP response for DNS and NTP
4. Refuse all

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
