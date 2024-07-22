
#!/bin/bash

# This script is for building
# all stack variations and check for errors
# during the mysqli and pdo connect.
# This Script is build for Linux
# Info:
# This Script works on WSL2 _but_ you cant use
# WSL2 Windows Host mounted paths for the data.

dc=$(which docker-compose)
user=$(whoami)
echo -e "### $dc \n"
echo -e "### $user \n"

docker rm -f $(docker ps -a -q)
$dc --env-file ./admin/.env up -d --build

# wait for mysql to initialize
sleep 5

docker exec -t phpdocker-php-fpm-1 bash -c "chmod -R 775 storage"
docker exec -t phpdocker-php-fpm-1 bash -c "chown -R www-data:www-data storage"
docker exec -t phpdocker-php-fpm-1 bash -c "chmod -R 775 bootstrap/cache"
docker exec -t phpdocker-php-fpm-1 bash -c "chown -R www-data:www-data bootstrap/cache"

docker exec -t phpdocker-php-fpm-1 bash -c "php artisan optimize:clear"
docker exec -t phpdocker-php-fpm-1 bash -c "php artisan storage:link"
docker exec -t phpdocker-php-fpm-1 bash -c "composer update"
docker exec -t phpdocker-php-fpm-1 bash -c "php artisan config:cache"
docker exec -t phpdocker-php-fpm-1 bash -c "php artisan migrate:fresh --seed"
docker exec -t phpdocker-php-fpm-1 bash -c "php artisan config:cache"
