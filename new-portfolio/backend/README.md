# Backend

## Change mongodb root password

    kubectl exec -it deployment.apps/mongodb -- mongosh

    use admin
    
    db.auth("admin", "old-password")

    db.changeUserPassword("admin", "new-password")