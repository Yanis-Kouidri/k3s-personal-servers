# GoatCounter

Cookieless web analytics for www.kouidri.fr: daily visits, pages, referrers and
the visitor's country, resolved from the client address with the GeoIP database
built into GoatCounter. The IP itself is not stored.

- Dashboard: https://stats.kouidri.fr
- Collection endpoint: https://www.kouidri.fr/count (first-party, routed to
  GoatCounter by `http-route.yaml`), also reachable at https://stats.kouidri.fr/count
- Database: SQLite on the `goatcounter-data` PVC

## Create the site and the first user

With no site in the database, https://stats.kouidri.fr shows a creation wizard
to anyone. Create the site from the CLI right after the first deployment:

```bash
kubectl exec -n goatcounter -it deployment/goatcounter -- \
  goatcounter db create site \
    -db sqlite+/home/goatcounter/goatcounter-data/db.sqlite3 \
    -vhost stats.kouidri.fr -user.email <email>
```

It asks for the password. The vhost must stay `stats.kouidri.fr`: the `/count`
route of www.kouidri.fr rewrites the Host header to it.

## Tracking snippet

Served by the website itself, so its CSP only needs `'self'` (`script-src`,
`connect-src`, `img-src`). `count.js` is downloaded from
https://stats.kouidri.fr/count.js (or https://gc.zgo.at/count.js) and copied into
the site:

```html
<script data-goatcounter="https://www.kouidri.fr/count" async src="/count.js"></script>
```

## Client address

GoatCounter prefers `Cf-Connecting-Ip`, `Fly-Client-Ip`, `X-Azure-Socketip` and
`X-Real-Ip` over `X-Forwarded-For`. The routes remove them, so the address used is
the right-most public entry of `X-Forwarded-For`, appended by Envoy (the Envoy
Service is `externalTrafficPolicy: Local`, the client address is preserved).

## Backup

Archived nightly by the host cron with `backups/general_pvc_backup.sh`, see the
`-- GoatCounter --` entry in `backups/crontab.bak`. The deployment is stopped for
the duration of the archive (`-S`) so the SQLite file is consistent.
