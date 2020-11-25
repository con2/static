#!/bin/bash
set -ueo pipefail

rm -f /etc/nginx/conf.d/default*

for INGRESS_HOSTNAME in $STATIC_SITES; do
  FILENAME=/etc/nginx/conf.d/$INGRESS_HOSTNAME.conf
  echo "Writing $FILENAME" > /dev/fd/2
  cat > $FILENAME << NONGINX
server {
    listen 80;
    server_name $INGRESS_HOSTNAME;
    root /srv/$INGRESS_HOSTNAME;
    charset utf-8;

    location / {
        try_files \$uri \$uri/index.html \$uri.html =404;
    }
}
NONGINX
done

exec "$@"
