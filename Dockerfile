FROM php:8.2-fpm-alpine

LABEL maintainer="cesaralejo@gmail.com"
LABEL version="1.0.1"
LABEL description="PHP-FPM: Composer, Laravel, PostgreSQL, LDAP y SMTP"

# Install system dependencies (Composer, Laravel, PostgreSQL, LDAP y SMTP)
RUN apk add --no-cache \
    curl \
    unzip \
    git \
    g++ \
    make \
    libzip-dev \
    zip \
    libpng-dev \
    freetype-dev \
    libjpeg-turbo-dev \
    libwebp-dev \
    libxpm-dev \
    oniguruma-dev \
    postgresql-dev \
    libxml2-dev \
    zlib-dev \
    icu-dev \
    tzdata \
    openldap-dev \
    msmtp \
    bash

# Config zona horaria a America/Bogota. | tzdata
RUN cp /usr/share/zoneinfo/America/Bogota /etc/localtime \
    && echo "America/Bogota" > /etc/timezone

# Install PHP extensions | pdo_mysql | pcntl | tokenizer xml ctype
RUN docker-php-ext-install \
    pdo \
    pdo_pgsql \
    gd \
    zip \
    opcache \
    mbstring \
    exif \
    bcmath \
    fileinfo \
    dom \
    intl \
    ldap

# Descarga e instala Composer globalmente.
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy the applicaton code directory contents to the working directory
COPY ./src .

# Instala las dependencias de Composer.
# --no-dev: Excluye las dependencias de desarrollo.
# --no-interaction: No pide entrada interactiva.
# --optimize-autoloader: Genera un autoloader optimizado para producción.
# --prefer-dist: Descarga paquetes desde sus archivos distribuidos cuando sea posible.
RUN composer install --no-dev --no-interaction --optimize-autoloader --prefer-dist

# Set permissions of the working directory to the www-data user
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache /var/www/html/upload \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache /var/www/html/upload

# Expose port 9000
EXPOSE 9000

# By default, the container start php-fpm
CMD ["php-fpm"]