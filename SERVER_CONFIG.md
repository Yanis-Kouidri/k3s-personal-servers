# Steps to config the server

> Tested on Ubuntu 24.04 on November 2025

## SSH

Get the ssh fingerprint on server (via web interface for example):

```bash
ssh-keygen -l -f /etc/ssh/ssh_host_ed25519_key.pub
```

SSH the server with password and add your client public key on `authorized_host` file.

Check if it works.

If yes, edit the file `/etc/ssh/sshd_config` on the server:

```bash
sudo vi /etc/ssh/sshd_config
```

**Comment:** `Include /etc/ssh/sshd_config.d/*.conf` to avoid overiding conf.

**Set:**

```ssh
PasswordAuthentication no
PermitRootLogin no
X11Forwarding no
PubkeyAuthentication yes
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

## Install K3s

```bash
sudo apt update && sudo apt upgrade -y
sudo ufw disable
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik" sh -
```

Check status and nodes:

```bash
sudo systemctl status k3s
sudo kubectl get nodes
```

Configure kubeconfig:

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
chmod 600 ~/.kube/config

echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
source ~/.bashrc
```

Check node:

```bash
kubectl get node
```

## Kubens

To easly change namespace

```bash
sudo apt install kubectx
```

## Helm

```bash
sudo snap install helm --classic
```

## Secrets with SOPS and age

This project uses [SOPS](https://github.com/getsops/sops) and [age](https://github.com/FiloSottile/age) to manage Kubernetes secrets.

### Prerequisites

- `sops` installed: [Here](https://github.com/getsops/sops/releases)
- `age` key pair generated
- `kubectl` configured for the target cluster

### Set up public key

```bash
export PUBLIC_AGE_KEY=age1XXX # Paste your age public key here
```

### Encrypt secrets

```bash
sops --encrypt --age "$PUBLIC_AGE_KEY" secrets.yaml > secrets.enc.yaml
```

### Decrypt and apply to Kubernetes

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

### IPv6 bridge to IPv4

If k3s was installed vanilla, it will not listen on IPv6 or provite IPv6 range.
Therefore, easiet way to handle IPv6 request is to create a bridge thanks to socat.

Install socat

```bash
sudo apt update && sudo apt install socat -y
```

Create a service here:

```bash
sudo vi /etc/systemd/system/ipv6-proxy@.service
```

And paste

```ini
[Unit]
Description=IPv6 to IPv4 Proxy Bridge for Port %i
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/socat TCP6-LISTEN:%i,ipv6only=1,reuseaddr,fork TCP4:127.0.0.1:%i
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Create 2 services one for port 80 and one for port 443

```bash
sudo systemctl daemon-reload

sudo systemctl enable --now ipv6-proxy@80

sudo systemctl enable --now ipv6-proxy@443
```

Check status:

```bash
sudo systemctl status ipv6-proxy@80
sudo systemctl status ipv6-proxy@443
```

Test from another machine, it should test both 80 and 443 thanks to redirection

```bash
curl -6 -v -L http://www.kouidri.fr
```

To be sure:

```bash
curl -6 -v -L https://www.kouidri.fr
```