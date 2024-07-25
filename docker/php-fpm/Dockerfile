FROM php:8.3-fpm
WORKDIR "/app1"

RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    zip \
    unzip\
    openssl\
    cron\
    nano\
    yaz\
    libyaz-dev \
    iputils-ping \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

# Install yaz extensions
RUN pecl install --force yaz
RUN docker-php-ext-enable yaz
# Install redis
RUN pecl install redis-5.3.3 && \
    docker-php-ext-enable redis
# Install imagick
RUN apt-get update && \
apt-get -y --no-install-recommends install --fix-missing libmagickwand-dev && \
rm -rf /var/lib/apt/lists/*
ARG IMAGICK_COMMIT="661405abe21d12003207bc8eb0963fafc2c02ee4"
RUN cd /usr/local/src && \
    git clone https://github.com/Imagick/imagick && \
    cd imagick && \
    git checkout ${IMAGICK_COMMIT} && \
    phpize && \
    ./configure && \
    make && \
    make install && \
    cd .. && \
    rm -rf imagick && \
    docker-php-ext-enable imagick
# Install PHP extensions
RUN docker-php-ext-install pdo_mysql mysqli mbstring exif pcntl bcmath gd zip intl gettext calendar

# Enable PHP extensions
RUN docker-php-ext-enable pdo_mysql mysqli mbstring exif pcntl bcmath gd zip intl gettext calendar

# Get latest Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
