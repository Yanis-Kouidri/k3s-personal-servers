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

1. Récupérer le mot de passe du compte de récupération (Secret `stalwart-env`,
   key `STALWART_RECOVERY_ADMIN`, valeur `admin:<password>`). Ce secret a été
   créé impérativement (hors Git, temporaire). **Ne jamais committer le mot de
   passe.**
2. `kubectl port-forward -n mail svc/stalwart-headless 8080:8080`
3. Ouvrir `http://127.0.0.1:8080/admin`, sign in avec le compte de récupération.
4. Assistant de configuration :
   - créer le compte **admin permanent** (ex: `postmaster@kouidri.fr` ou un
     compte administrateur dédié) ;
   - ajouter le domaine **kouidri.fr** ;
   - configurer les listeners **SMTP (25)**, **SMTPS (465)**, **Submission (587)**,
     **IMAPS (993)** et attacher le certificat Let's Encrypt monté dans le pod :
     certificat fichier `/etc/stalwart/tls/tls.crt` + clé `/etc/stalwart/tls/tls.key`
     (Settings → Server → TLS → Certificates) ;
   - générer la clé **DKIM** du domaine (Settings → Domain → kouidri.fr → Keys),
     exporter la valeur TXT ;
   - configurer une adresse de reporting DMARC si souhaité.
5. Extraire tous les enregistrements DNS depuis l'UI (voir section DNS).
6. **Supprimer le mécanisme de récupération** :
   `kubectl delete secret -n mail stalwart-env` puis redémarrer le pod
   (`kubectl rollout restart statefulset/stalwart -n mail`).

Vérifications post-bootstrap :

```bash
kubectl port-forward -n mail svc/stalwart-headless 8080:8080 &
curl -sk https://mail.kouidri.fr/                 # webmail (remplace le 503)
curl -sk -o /dev/null -w '%{http_code}\n' https://mail.kouidri.fr/admin   # admin (si exposé)
openssl s_client -connect mail.kouidri.fr:465 -servername mail.kouidri.fr \
  </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer   # CN=mail.kouidri.fr LE
openssl s_client -connect mail.kouidri.fr:993 -servername mail.kouidri.fr \
  </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer
openssl s_client -connect mail.kouidri.fr:25 -starttls smtp -servername mail.kouidri.fr \
  </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer
```

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

Résultats effectués le 21/08/2026 (avant la finalisation du wizard) :

| Test | Résultat |
|------|----------|
| `nc -vz mail.kouidri.fr 25` | ✅ CONNECTED (SMTP Stalwart répond `220`) |
| `nc -vz mail.kouidri.fr 465` | ✅ CONNECTED (SMTPS — cert self-signed `rcgen` par défaut en attendant l'assignation du cert LE) |
| `nc -vz mail.kouidri.fr 587` | ✅ CONNECTED |
| `nc -vz mail.kouidri.fr 993` | ✅ CONNECTED (IMAPS — idem) |
| TLS 443 (Envoy, SNI mail.kouidri.fr) | ✅ Cert Let's Encrypt, SAN `mail.kouidri.fr` inclus |
| HTTP→HTTPS | ✅ 301 vers https://mail.kouidri.fr |
| https://mail.kouidri.fr/ | ⚠️ `503` tant que le wizard n'a pas configuré le listener HTTP/webmail |
| **Open relay (sans auth, RCPT vers gmail)** | ✅ **`550 5.1.2 Relay not allowed.`** |
| Port 25 sortant (OVH) | ✅ non bloqué (connexion à gmail-smtp-in réussie) |
| DNS A / AAAA / MX / SPF | ✅ vérifiés |
| PTR IPv4 + IPv6 | ❌ **`vps-f4edccd1.vps.ovh.net.`** → à corriger chez OVH |

```bash
# Après finalisation du wizard :
openssl s_client -connect mail.kouidri.fr:993 -servername mail.kouidri.fr \
  < /dev/null 2>/dev/null | openssl x509 -noout -subject -dates
openssl s_client -connect mail.kouidri.fr:465 -servername mail.kouidri.fr \
  < /dev/null 2>/dev/null | openssl x509 -noout -subject -dates
nc -vz mail.kouidri.fr 25; nc -vz mail.kouidri.fr 465
nc -vz mail.kouidri.fr 587; nc -vz mail.kouidri.fr 993
dig +short MX kouidri.fr
dig +short TXT kouidri.fr | grep spf
```
