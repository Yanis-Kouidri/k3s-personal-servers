# Stalwart Mail Server — `mail` namespace

Serveur de messagerie [Stalwart](https://stalw.art) (v0.16.18) déployé sur le
cluster K3s mono-node, pour le domaine **kouidri.fr** (hostname `mail.kouidri.fr`).

Déploiement 100% déclaratif piloté par FluxCD (kustomization `apps/mail`).

## Architecture Kubernetes

| Élément      | Description |
|--------------|-------------|
| Namespace    | `mail` |
| StatefulSet  | `stalwart`, 1 replica, image `stalwartlabs/stalwart:v0.16.18` (PINGÉE, pas de `latest`) |
| Stockage     | RocksDB **local** (`config.json` → RocksDb `/var/lib/stalwart`) |
| PVC          | `stalwart-data`, StorageClass `local-path` (default), 20 Gi, RWO |
| Service LB   | `stalwart` : **25/465/587/993** (K3s ServiceLB / klipper-lb), **pas** de 80/443/8080 |
| Service headless | `stalwart-headless` : http:80 (webmail), mgmt:8080 (admin, interne) |
| Certificat   | cert-manager `mail-kouidri-tls` (Let's Encrypt prod, HTTP01 via Envoy) monté dans le pod pour TLS mail |
| HTTPRoute    | `mail-kouidri-fr` → Envoy Gateway (section https) → webmail |
| Sécurité     | No open relay, mgmt 8080 non exposé, NetworkPolicy, pods non-root (uid 2000, PSS baseline) |

Flux GitOps : sources dans `apps/kustomization.yaml` (agrège `apps/mail`).

## Ports

- `25`   SMTP entrant (Internet)
- `465`  SMTPS (TLS implicite)
- `587`  SMTP Submission (authentifié, STARTTLS)
- `993`  IMAPS
- `443`  Web UI via Envoy (TLS terminé par cert-manager)
- `8080` Admin (management) — **interne uniquement**, accès via `kubectl port-forward`

## DNS à créer chez OVH (manuel)

| Type | Nom | Valeur | Priorité | TTL |
|------|-----|--------|----------|-----|
| A    | mail | `91.134.243.146` | – | 3600 |
| AAAA | mail | `2001:41d0:305:2100::6ef0` | – | 3600 |
| MX   | (vide) | `mail.kouidri.fr.` | 10 | 3600 |
| TXT  | (vide) | `v=spf1 mx -all` | – | 3600 |
| TXT  | `_dmarc` | `v=DMARC1; p=none; rua=mailto:<admin>@kouidri.fr` | – | 3600 |
| TXT  | `<selector>._domainkey` | *(valeur DKIM générée par Stalwart)* | – | 3600 |

> ⚠️ **PTR / Reverse DNS** : à configurer dans le manager OVH.
> `91.134.243.146 → mail.kouidri.fr` et `2001:41d0:305:2100::6ef0 → mail.kouidri.fr`.
> Vérifié le 21/08/2026 : actuellement `vps-f4edccd1.vps.ovh.net.` (INCORRECT).

> ⚠️ **Firewall OVH** : ouvrir `25/tcp`, `465/tcp`, `587/tcp`, `993/tcp`, `443/tcp`
> (et `22/tcp` pour SSH). Ne **pas** ouvrir `8080`.

## Premier bootstrap (compte admin)

1. Récupérer le mot de passe du compte de récupération (Secret `stalwart-env`, key `STALWART_RECOVERY_ADMIN`).
2. `kubectl port-forward -n mail svc/stalwart-headless 8080:8080`
3. Ouvrir `http://127.0.0.1:8080/admin` et se connecter.
4. Assistant : créer le domaine `kouidri.fr`, le compte admin permanent, configurer les listeners et le certificat TLS (`/etc/stalwart/tls/tls.crt`).
5. Extraire les enregistrements DNS (DKIM/SPF/DMARC/MTA-STS/TLS-RPT) depuis l'UI.
6. **Supprimer le mécanisme de récupération** : `kubectl delete secret -n mail stalwart-env` puis redémarrer le pod.

## Sécurité (open relay)

Le serveur n'accepte aucun relay non authentifié :
- port 25 = SMTP entrant (destinataires du domaine uniquement)
- port 587 = Submission **authentifié**
- port 465 = SMTPS **authentifié**
- Toute tentative d'envoi vers un destinataire externe sans auth → refusée (`554`).

## Ressources

```yaml
requests: { cpu: 250m, memory: 512Mi }
limits:   { cpu: "2",    memory: 2Gi }
```
Choix réaliste pour un serveur mail perso mono-node (cluster déjà ~9 Gi utilisé
par Immich/Minecraft/etc.). Ajustable dans `statefulset.yaml`.

## Sauvegarde / Restauration

⚠️ **Un PVC n'est PAS une sauvegarde.** Le backup se fait au niveau du host
(dans `/var/lib/rancher/k3s/storage/`), comme pour les autres services (`./backups/`).

À sauvegarder :
- données Stalwart (volume `stalwart-data` → répertoire local-path sur le node)
- configuration + clés **DKIM** (récupérées via l'UI et à conserver hors Git)
- Secret `mail-kouidri-tls` (cert) — renouvelé automatiquement par cert-manager

À mettre en place (adapté de `./backups/general_pvc_backup.sh`) : copie périodique
du répertoire du PVC vers un stockage externe. **Documenté, non encore implémenté**
tant que l'utilisateur ne le valide pas.

Restauration : recréer le PVC avec l'ancien contenu puis relancer le StatefulSet.

## Mise à jour

1. Modifier `image: stalwartlabs/stalwart:v0.16.18` dans `statefulset.yaml` (vérifier
   la version stable sur https://stalw.art/docs).
2. Commit + push → Flux applique (rolling update, PVC conservé).

## Tests

```bash
openssl s_client -connect mail.kouidri.fr:993 -servername mail.kouidri.fr \
  < /dev/null 2>/dev/null | openssl x509 -noout -subject -dates
openssl s_client -connect mail.kouidri.fr:465 -servername mail.kouidri.fr \
  < /dev/null 2>/dev/null | openssl x509 -noout -subject -dates
nc -vz mail.kouidri.fr 25; nc -vz mail.kouidri.fr 465
nc -vz mail.kouidri.fr 587; nc -vz mail.kouidri.fr 993
dig +short MX kouidri.fr
dig +short TXT kouidri.fr | grep spf
```
