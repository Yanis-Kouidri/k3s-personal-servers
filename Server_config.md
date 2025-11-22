# Steps to config the server 

Tested on Ubuntu 24.10 on November 2025

## SSH

get the ssh finger print on serveur (via web interface for example)

    ssh-keygen -l -f /etc/ssh/ssh_host_ed25519_key.pub

ssh the serveur with password and add your client public key on authorized_host file 

check if it works

if yes edit the file /etc/ssh/sshd_config on the server

    sudo vi /etc/ssh/sshd_config

Comment : Include /etc/ssh/sshd_config.d/*.conf to avoid overiding conf

Set :

    PasswordAuthentication no
    PermitRootLogin no
    X11Forwarding no
    PubkeyAuthentication yes

check :
    sudo sshd -t

restart :
    sudo systemctl restart ssh

On client side save the config on .ssh/config
Adapt user, port, IP ADDRESS and itentiyfile (private key)

```
Host my-vps
    HostName <IP_ADDRESS>
    User ubuntu
    Port 22
    IdentityFile ~/.ssh/id_ed25519_vps
```

## Shell

Set a good host name :

    sudo hostnamectl set-hostname vps-ovh-prod

Install dotfiles : https://github.com/Yanis-Kouidri/dotfiles

## Install K3s

sudo apt update && sudo apt upgrade -y

sudo ufw disable

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik" sh -

sudo systemctl status k3s

sudo kubectl get nodes

mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
chmod 600 ~/.kube/config

echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
source ~/.bashrc

kubectl get node

## Kubens

sudo apt install kubectx

## Helm

sudo snap install helm --classic

## Longhorn

helm repo add longhorn https://charts.longhorn.io

helm repo update

helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace --version VERSION

(look for the latest version on GitHub)

### Access UI

Port forward

```bash
kubectl port-forward svc/longhorn-frontend 8080:80 -n longhorn-system > /dev/null 2>&1 &
```

Setup a tunnel from the local PC (not the VPS)

```bash
ssh vps-name -NL 8080:localhost:8080
```

Access from client to http://localhost:8080

To kill port forward

Find the pid with :

    ss -plantu | grep 8080

Then kill with

    kill -9 PID

