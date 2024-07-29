#!/bin/bash

### sh docker/release.sh

# Get all arguments
for args in "$@"; do
  case $args in
  env=*)
    ENV="${args#*=}"
    shift
    ;;
  -seed)
    MIGRATESEED=true
    shift
    ;;
  *)
    echo "Invalid argument: $args"
    ;;
  esac
done

dc=$(which docker-compose)
user=$(whoami)
echo -e "### $dc \n"
echo -e "### $user \n"

# docker rm -f $(docker ps -a -q)
docker rm -f docker-lemp-php-fpm-9001
docker rm -f docker-lemp-php-fpm-9002
docker rm -f docker-lemp-nginx
docker rm -f docker-lemp-mysql
docker rm -f docker-lemp-redis

docker network prune -f

$dc --env-file ./admin/.env up -d --build

# wait for mysql to initialize
sleep 5
docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' docker-lemp-mysql
#docker network ls
docker network inspect docker_lemp_network

### 9001
docker exec -i docker-lemp-php-fpm-9001 bash -c "ping mysql -c 4"
docker exec -i docker-lemp-php-fpm-9001 bash -c "chmod -R 775 storage"
docker exec -i docker-lemp-php-fpm-9001 bash -c "chown -R www-data:www-data storage"
docker exec -i docker-lemp-php-fpm-9001 bash -c "chmod -R 775 bootstrap/cache"
docker exec -i docker-lemp-php-fpm-9001 bash -c "chown -R www-data:www-data bootstrap/cache"

docker exec -i docker-lemp-php-fpm-9001 bash -c "php artisan optimize:clear"
docker exec -i docker-lemp-php-fpm-9001 bash -c "php artisan storage:link"
docker exec -i docker-lemp-php-fpm-9001 bash -c "composer update"
docker exec -i docker-lemp-php-fpm-9001 bash -c "php artisan config:cache"

### 9002
docker exec -i docker-lemp-php-fpm-9002 bash -c "chmod -R 775 storage"
docker exec -i docker-lemp-php-fpm-9002 bash -c "chown -R www-data:www-data storage"
docker exec -i docker-lemp-php-fpm-9002 bash -c "chmod -R 775 bootstrap/cache"
docker exec -i docker-lemp-php-fpm-9002 bash -c "chown -R www-data:www-data bootstrap/cache"

docker exec -i docker-lemp-php-fpm-9002 bash -c "php artisan optimize:clear"
docker exec -i docker-lemp-php-fpm-9002 bash -c "php artisan storage:link"
#docker exec -i docker-lemp-php-fpm-9002 bash -c "composer update"
docker exec -i docker-lemp-php-fpm-9002 bash -c "php artisan config:cache"

# if argument seed is passed run this command
# docker exec -it docker-lemp-php-fpm-9001 bash -c "php artisan migrate:fresh --seed"
if [ "$MIGRATESEED" ]; then
    docker exec -it docker-lemp-php-fpm-9001 bash -c "php artisan migrate:fresh --seed"
    docker exec -i docker-lemp-php-fpm-9001 bash -c "php artisan config:cache"
fi

