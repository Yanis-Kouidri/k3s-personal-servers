# Backend

## Change mongodb root password

```bash
kubectl exec -it deployment.apps/mongodb -- mongosh
```

```bash
use admin
```

```bash
db.auth("admin", "old-password")
```

```bash
db.changeUserPassword("admin", "new-password")
```

Think to update `secrets.yaml` and encrypt it in `secrets.enc.yaml`

## Back up

```bash
crontab -e
```

And add this line:

```bash
0 3 * * * /home/ubuntu/k3s-personal-servers/personal-website/backend/backup.sh >> /home/ubuntu/backups/portfolio/backup-backend.log 2>&
```

