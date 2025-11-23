# Personal k3s Homelab Cluster - All-in-One Kubernetes Setup

This repository contains my complete **Infrastructure as Code (IaC)** setup for a lightweight, personal Kubernetes cluster using **k3s**.  
It runs on a single node (or small cluster) on a VPS and hosts all my self-hosted services: personal website, game servers, photo management, code quality tools, monitoring, and more.

## Hosted Services

Currently running (or planned):

- **Immich** – Self-hosted Google Photos alternative
- **SonarQube** – Code quality & security analysis
- **Minecraft Server** (via Itzg Docker image)
- **Personal Website** (using MERN stack)
- **Longhorn** – Distributed block storage with backups
- **Cert-Manager** – Automatic SSL certificates
- **Envoy API Gateway** - Reverse proxy
- **Wireguard** - Fast and secure VPN
- And more to come…

## Prerequisites

- A Linux server (Ubuntu/Debian recommended) with at least:
  - 8 GB RAM (16+ recommended)
  - 4+ CPU cores
  - 200+ GB SSD/NVMe
- A domain name (for SSL and pretty URLs)

## How to set up

Look Server_config.md