# Personal k3s Homelab Cluster - All-in-One Kubernetes Setup

This repository contains my complete **Infrastructure as Code (IaC)** setup for a lightweight, personal Kubernetes cluster using **k3s**.  
It runs on a single node on a VPS and hosts all my self-hosted services.

## Hosted Services

Currently running:

- **Immich** – Self-hosted Google Photos alternative
- **SonarQube** – Code quality & security analysis
- **Minecraft Server** (via Itzg Docker image)
- **Personal Website** (using MERN stack) and accessible from TOR network
- **Cert-Manager** – Automatic SSL certificates
- **Envoy API Gateway** - Reverse proxy
- **Wireguard** - Fast and secure VPN
- **n8n** - Workflow automation platform
- And more to come…

### Personal website

Accessible from https://www.kouidri.fr or http://kouidri6bhboadbevagrvs52nmyvfhgafavqozvs6b756bzh3e4sd7qd.onion using [TOR browser](https://www.torproject.org) (Work in progress)

## Prerequisites

- A Linux server (Ubuntu recommended) with at least:
  - 8 GB RAM (16+ recommended)
  - 4+ CPU cores
  - 200+ GB SSD/NVMe
- A domain name (for SSL and pretty URLs)

## How to set up

Look `SERVER_CONFIG.md`