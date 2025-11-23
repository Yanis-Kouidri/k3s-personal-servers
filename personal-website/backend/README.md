# Backend

## Change mongodb root password

    kubectl exec -it deployment.apps/mongodb -- mongosh

    use admin
    
    db.auth("admin", "old-password")

    db.changeUserPassword("admin", "new-password")

Think to update `secrets.yaml` and encrypt it in `secrets.enc.yaml`