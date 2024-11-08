#!/usr/bin/env bash
# License: The MIT License (MIT)
# Author Amir Hoss (http:amirhome.com)

dc="docker compose"

echo -e "### $dc running..\n"

# docker network prune -f
$dc --env-file ./symlink_app1/.env down
$dc --env-file ./symlink_app1/.env build
$dc --env-file ./symlink_app1/.env up -d --remove-orphans

# Clean docker unused image and container
# docker system prune -a