FROM php:8.3.22-fpm

LABEL maintainer="cesaralejo@gmail.com"
LABEL version="1.0.0"
LABEL description="Imagen base PHP-FPM"

# Arguments defined in docker-compose.yml
ARG user
ARG uid

# Set working directory
WORKDIR /var/www

# Establece la zona horaria (ejemplo: UTC)
ENV TZ=America/Bogota

# Install system dependencies utf8_mime2text
#oniguruma-dev
#libsasl2-dev \
#libsasl2-modules \
#libwebp-dev \
#libxpm-dev \
#libgd-dev \
#zlib1g-dev \
RUN apt-get update && apt-get install -y \
    build-essential \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    locales \
    zip \
    jpegoptim optipng pngquant gifsicle \
    vim \
    libzip-dev \
    unzip \
    git \
    curl \
    #IMAP
    libssl-dev \
    libicu-dev \
    libc-client-dev \
    libkrb5-dev \
    #PGSQL
    libpq-dev \
    #LDAP
    libldap2-dev \
    libxml2-dev \
    libonig-dev

# Clear cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PHP extensions | pdo_mysql
RUN docker-php-ext-install mbstring exif pcntl bcmath zip

RUN docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql
RUN docker-php-ext-install pdo pdo_pgsql pgsql

RUN docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/
RUN docker-php-ext-install ldap

RUN docker-php-ext-configure intl
RUN docker-php-ext-install intl

RUN docker-php-ext-configure imap --with-kerberos --with-imap-ssl
RUN docker-php-ext-install imap

# --with-webp --with-xpm
RUN docker-php-ext-configure gd --enable-gd --with-freetype --with-jpeg
RUN docker-php-ext-install -j$(nproc) gd

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && composer --ansi --version --no-interaction

# Copy composer.lock and composer.json
#COPY ./src/composer.lock ./src/composer.json /var/www/

# Create system user to run Composer and Artisan Commands
RUN useradd -G www-data,root -u $uid -d /home/$user $user
RUN mkdir -p /home/$user/.composer && \
    chown -R $user:$user /home/$user

# Copy the applicaton code directory contents to the working directory
COPY ./src /var/www

# Set permissions of the working directory to the www-data user
RUN chown -R www-data:www-data \ 
    /var/www/viaticos/web/upload

# Assign writing permissions to logs and framework directories
RUN chmod 775 -R /var/www/viaticos/web/upload /var/www/plaguicidas/upload

# Install project dependencies | --no-autoloader --no-ansi --no-interaction --no-progress --no-scripts
# RUN composer install --optimize-autoloader --no-dev

#RUN php artisan key:generate
#RUN php artisan storage:link
#RUN php artisan migrate

#RUN composer require laravel/octane spiral/roadrunner
#RUN php artisan octane:install --server="swoole"

# Actualiza la hora del sistema
RUN ln -sf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone

# Expose port 9000 and start php-fpm server
EXPOSE 9000
CMD ["php-fpm"]

# Server Octane
#RUN php artisan actane:install --server="swoole"

#CMD php artisan octane:start --server="swoole" --host="0.0.0.0"
#EXPOSE 8000