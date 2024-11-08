#!/bin/sh

### DB_HOST=mysql
### REDIS_HOST=redis
### ln -s your_app1 symlink_app1
### ln -s your_app2 symlink_app2
### su deploy
### --- sudo chown -R deploy:deploy /home/deploy/patientv2/docker_lemp/
### --- git reset --hard && git clean -fd && git pull
### sh docker/release.sh -seed -doc

# Check if the current user is 'deploy'
if [ "$(whoami)" = "deploy" ]; then
  echo "Running as deploy user"

  # Command 1
  sudo chown -R deploy:deploy /home/deploy/patientv2/docker_lemp/

  # Command 2
  git reset --hard && git clean -fd && git pull

  # Sync uploads folder
  sudo chown -R deploy:deploy /home/deploy/patientv2/admin/storage/app/public/uploads/
  rsync -avzh patientsclinics@160.153.244.148:/home/patientsclinics/public_html/patient_code/public/uploads/ /home/deploy/patientv2/admin/storage/app/public/uploads
  ## ]&E{?d{{djl1

  ## docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "chown -R www-data:www-data ."

  # Existing commands in release.sh
  # ...
else
  echo "This script must be run as the deploy user."

  exit 1
  # get path of this script
  SCRIPT=$(readlink -f "$0")
  SCRIPTPATH=$(dirname "$SCRIPT")

  # Stop all containers and remove all containers
  docker stop $(docker ps -a -q)
  docker rm $(docker ps -a -q)
  # Remove all images
  # docker rmi $(docker images -q)
  # Remove all volumes and networks
  docker volume prune -f
  docker network prune -f
  
  rm -rf $SCRIPTPATH/mysql/data/*
  rm -rf $SCRIPTPATH/mysql/logs/*

fi

# Get all arguments
for args in "$@"; do
  case $args in
  env=*)
    ENV="${args#*=}"
    shift
    ;;
  -seed)
    MIGRATESEED=false
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
if [ -f "symlink_app1/.env.admin" ]; then
  export $(cat symlink_app1/.env.admin | grep -v '#' | awk '/=/ {print $1}')
  sudo cp symlink_app1/.env.admin symlink_app1/.env

else
  echo "File .env not found"
  exit 1
fi

# dc=$(which docker-compose)

user=$(whoami)

echo -e "### $user \n"
echo -e "### ${APP_NAME} \n"

### docker rm -f $(docker ps -a -q)
### docker rm -f docker-lemp-${APP_NAME}-php-fpm-9001
### docker rm -f docker-lemp-${APP_NAME}-php-fpm-9002
### docker rm -f docker-lemp-nginx
### docker rm -f docker-lemp-mysql
### docker rm -f docker-lemp-redis
if [ "$DOC" ]; then
  # echo -e "### $dc \n"

  # dc="docker compose"

  # docker network prune -f
  # $dc --env-file ./symlink_app1/.env down
  # $dc --env-file ./symlink_app1/.env up -d --build
  sudo sh docker/docker_up.sh

fi

# wait for mysql to initialize
sleep 3
docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' docker-lemp-${APP_NAME}-mysql

### docker network ls
### docker network inspect docker_lemp_network

### 9001 Admin app1 --------------------------------------------------------------------------------------------------
docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "ping mysql -c 4"
if [ "$(whoami)" = "deploy" ]; then
  docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "chown -R www-data:www-data ."
  docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "git config --global --add safe.directory /app1"
  docker exec -it docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "git reset --hard origin/master && git clean -df && git pull"

fi

docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "chmod -R 775 storage"
docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "chmod -R 775 bootstrap/cache"

docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "composer dump-autoload"
docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan optimize:clear"
docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan storage:link"
docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "composer update"

### 9002 Chat app2 --------------------------------------------------------------------------------------------------
if [ "$(whoami)" = "deploy" ]; then
  docker exec -i docker-lemp-${APP_NAME}-php-fpm-9002 bash -c "chown -R www-data:www-data ."
  docker exec -i docker-lemp-${APP_NAME}-php-fpm-9002 bash -c "git config --global --add safe.directory /app2"
  docker exec -i docker-lemp-${APP_NAME}-php-fpm-9002 bash -c "git reset --hard origin/master && git clean -df && git pull"
fi

docker exec -i docker-lemp-${APP_NAME}-php-fpm-9002 bash -c "chmod -R 775 storage"
docker exec -i docker-lemp-${APP_NAME}-php-fpm-9002 bash -c "chmod -R 775 bootstrap/cache"
### docker exec -i docker-lemp-${APP_NAME}-php-fpm-9002 bash -c "chown -R www-data:www-data storage"
### docker exec -i docker-lemp-${APP_NAME}-php-fpm-9002 bash -c "chown -R www-data:www-data bootstrap/cache"

docker exec -i docker-lemp-${APP_NAME}-php-fpm-9002 bash -c "php artisan optimize:clear"
docker exec -i docker-lemp-${APP_NAME}-php-fpm-9002 bash -c "php artisan storage:link"

### Test to connect to mysql
docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan migrate:status"

# if argument seed is passed run this command
if [ "$MIGRATESEED" ]; then
  docker exec -it docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan migrate:fresh --seed"
else
  docker exec -it docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan migrate --force"
fi

### After migrate we need to run queue and regenerate media library
docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "nohup php artisan queue:work --daemon >> storage/logs/laravel.log &"
docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan queue:failed"
docker exec -it docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan media-library:regenerate --only-missing"
# php artisan media-library:clear
# php artisan media-library:regenerate --only-missing

### Don't cache config
if [ "$(whoami)" = "deploy" ]; then
  docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan config:cache"
  docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan optimize"

  docker exec -i docker-lemp-${APP_NAME}-php-fpm-9002 bash -c "php artisan config:cache"
  docker exec -i docker-lemp-${APP_NAME}-php-fpm-9002 bash -c "php artisan optimize"
fi

docker ps
