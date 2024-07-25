#!/bin/bash


dc=$(which docker-compose)
user=$(whoami)
echo -e "### $dc \n"
echo -e "### $user \n"

# docker rm -f $(docker ps -a -q)
docker rm -f docker-lemp-php-fpm
docker rm -f docker-lemp-nginx
docker rm -f docker-lemp-mysql
docker rm -f docker-lemp-redis

$dc --env-file ./admin/.env up -d --build

# wait for mysql to initialize
sleep 5

docker exec -i docker-lemp-php-fpm bash -c "chmod -R 775 storage"
docker exec -i docker-lemp-php-fpm bash -c "chown -R www-data:www-data storage"
docker exec -i docker-lemp-php-fpm bash -c "chmod -R 775 bootstrap/cache"
docker exec -i docker-lemp-php-fpm bash -c "chown -R www-data:www-data bootstrap/cache"

docker exec -i docker-lemp-php-fpm bash -c "php artisan optimize:clear"
docker exec -i docker-lemp-php-fpm bash -c "php artisan storage:link"
docker exec -i docker-lemp-php-fpm bash -c "composer update"
docker exec -i docker-lemp-php-fpm bash -c "php artisan config:cache"
docker exec -it docker-lemp-php-fpm bash -c "php artisan migrate:fresh --seed"
docker exec -i docker-lemp-php-fpm bash -c "php artisan config:cache"
