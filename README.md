# Con2 multi-site static file serving

We have a whole host of archived static sites we want to host until the end of time. This is the Way.

See [Static sites in Con2 wiki](https://outline.con2.fi/doc/static-sites-avLCfnRKAY).

## How it works

Each site lives in a Garage bucket named after its hostname (`2023.tracon.fi` and so on)
and is served by Garage's own web endpoint, which picks the bucket by the `Host` header.
The Gateway in the `static` namespace terminates TLS for every hostname in
`chart/values-production.yaml` and routes to that endpoint. There is no web server of
our own in this repository. `.github/workflows/cicd.yml` runs `helm upgrade --install static chart`
into namespace `static` on every push to master.

```sh
helm lint chart -f chart/values-production.yaml
helm template static chart -f chart/values-production.yaml
```

Garage serves `foo/index.html` for `/foo/`, and redirects `/foo` to `/foo/` when there is
no object named `foo` but `foo/index.html` exists.

## Shared media of the tracontent-premium sites

The sites burned from tracontent-premium link to `/media/...` files that lived in one shared
Minio bucket. They are served from the single Garage bucket `tracontent-media`: for the sites
listed under `sharedMedia.sites`, the HTTPRoute rewrites the Host header to that bucket name
for `/media` requests, and Garage serves it like any other site bucket. One copy, no
per-site duplication. `chart/migrate-media-from-minio.job.yaml` copied the files over.

## Adding a site

1. Add the hostname to `sites` in `chart/values-production.yaml` and push:
   CI deploys the Gateway, and cert-manager extends the certificate.
2. Create and enable the bucket: `bin/garage-buckets.sh <hostname>`.
3. Upload the files with the `static` Garage key (`garage.con2.fi`, region `garage`,
   path-style addressing), for example
   `rclone copy ./site garage:<hostname>` or tracontent-premium's `manage.py burn`.
4. Point DNS at qb.

## Migration from Minio (runbook, 2026-10)

The sites used to be prefixes of the Minio `static` bucket behind an nginx Deployment in
this namespace. Buckets, the `static` Garage key and the ReferenceGrant already exist.

1. Copy the data: create `static-migrate-credentials` and apply
   `chart/migrate-from-minio.job.yaml` as its header says, and wait for the Job to
   finish (about 37 000 objects, 2.5 GiB). Spot-check from inside the cluster, for example

   ```
   kubectl -n static run curl --rm -i --restart=Never --image=curlimages/curl -- \
     curl -sI -H 'Host: 2023.tracon.fi' http://garage.garage.svc.cluster.local:3902/liput
   ```

   expecting `200` with `content-type: text/html`.
2. Deploy the Gateway (push, or the `helm upgrade` from `cicd.yml`). The old
   Ingress keeps serving while cert-manager issues `static-tls`; wait for
   `kubectl -n static get certificate static-tls` to be Ready.
3. Remove the old serving path, which Helm never managed:

   ```
   kubectl -n static delete ingress static deployment nginx service nginx configmap nginx
   kubectl -n static delete job static-migrate-from-minio secret static-migrate-credentials
   ```

4. Check a few sites over HTTPS, then after a couple of weeks delete the Minio `static`
   bucket and the `tracontent-static-write` Minio policy.
