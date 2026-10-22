#!/bin/sh
set -e
cd /var/www/html
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan migrate --force
# Seed admin/demo data only once (set RUN_SEED=true in Render env, then remove it)
if [ "$RUN_SEED" = "true" ]; then php artisan db:seed --force; fi
exec /usr/bin/supervisord -c /etc/supervisord.conf
