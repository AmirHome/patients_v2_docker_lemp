#!/bin/sh

### DB_HOST=mysql
### REDIS_HOST=redis
### ln -s your_app1 symlink_app1
### ln -s your_app2 symlink_app2
### su deploy
### --- sudo chown -R deploy:deploy /home/deploy/docker_lemp/
### --- git reset --hard && git clean -fd && git pull
### sh docker/release.sh -seed -doc

# Check if the current user is 'deploy'
if [ "$(whoami)" = "deploy" ]; then
  echo "Running as deploy user"

  # Command 1
  sudo chown -R deploy:deploy /home/deploy/docker_lemp/

  # Command 2
  git reset --hard && git clean -fd && git pull

  # Existing commands in release.sh
  # ...
else
  echo "This script must be run as the deploy user."
  # exit 1

fi

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
  -mini)
    MINI=true
    shift
    ;;
  -doc)
    DOC=false
    shift
    ;;
  *)
    echo "Invalid argument: $args"
    ;;
  esac
done

# Read the .env file
if [ -f "symlink_app1/.env" ]; then
  export $(cat symlink_app1/.env | grep -v '#' | awk '/=/ {print $1}')
else
  echo "File .env not found"
  exit 1
fi

# dc=$(which docker-compose)
dc="docker compose"
user=$(whoami)
echo -e "### $dc \n"
echo -e "### $user \n"
echo -e "### ${APP_NAME} \n"


# docker rm -f $(docker ps -a -q)
# docker rm -f docker-lemp-${APP_NAME}-php-fpm-9001
# docker rm -f docker-lemp-${APP_NAME}-php-fpm-9002
# docker rm -f docker-lemp-nginx
# docker rm -f docker-lemp-mysql
# docker rm -f docker-lemp-redis
if [ "$DOC" ]; then

  docker network prune -f

  $dc down
  $dc --env-file ./symlink_app1/.env up -d --build
fi

# wait for mysql to initialize
sleep 3
docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' docker-lemp-${APP_NAME}-mysql

#docker network ls
# docker network inspect docker_lemp_network

### 9001 Admin app1 --------------------------------------------------------------------------------------------------
docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "ping mysql -c 4"
if [ "$(whoami)" = "deploy" ]; then
  docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "chown -R www-data:www-data ."
  docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "git config --global --add safe.directory /app1"
  docker exec -it docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "git reset --hard && git clean -df && git pull"
fi

docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "chmod -R 775 storage"
docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "chmod -R 775 bootstrap/cache"
# docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "chown -R www-data:www-data storage"
# docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "chown -R www-data:www-data bootstrap/cache"

docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan optimize:clear"
docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan storage:link"
docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "composer update"
#docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan key:generate"

docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "nohup php artisan queue:work --daemon >> storage/logs/laravel.log &"
docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan queue:failed"

### 9002 Chat app2 --------------------------------------------------------------------------------------------------
if [ "$(whoami)" = "deploy" ]; then
  docker exec -i docker-lemp-${APP_NAME}-php-fpm-9002 bash -c "chown -R www-data:www-data ."
  docker exec -i docker-lemp-${APP_NAME}-php-fpm-9002 bash -c "git config --global --add safe.directory /app2"
  docker exec -i docker-lemp-${APP_NAME}-php-fpm-9002 bash -c "git reset --hard && git clean -df && git pull"
fi


docker exec -i docker-lemp-${APP_NAME}-php-fpm-9002 bash -c "chmod -R 775 storage"
docker exec -i docker-lemp-${APP_NAME}-php-fpm-9002 bash -c "chmod -R 775 bootstrap/cache"
# docker exec -i docker-lemp-${APP_NAME}-php-fpm-9002 bash -c "chown -R www-data:www-data storage"
# docker exec -i docker-lemp-${APP_NAME}-php-fpm-9002 bash -c "chown -R www-data:www-data bootstrap/cache"

docker exec -i docker-lemp-${APP_NAME}-php-fpm-9002 bash -c "php artisan optimize:clear"
docker exec -i docker-lemp-${APP_NAME}-php-fpm-9002 bash -c "php artisan storage:link"


# if argument seed is passed run this command
if [ "$MIGRATESEED" ]; then
    docker exec -it docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan migrate:fresh --seed"
else
    docker exec -it docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan migrate --force"
fi


if [ "$(whoami)" = "deploy" ]; then
  docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan config:cache"
  docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan optimize"

  docker exec -i docker-lemp-${APP_NAME}-php-fpm-9002 bash -c "php artisan config:cache"
  docker exec -i docker-lemp-${APP_NAME}-php-fpm-9002 bash -c "php artisan optimize"
fi

docker ps
