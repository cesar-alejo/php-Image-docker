#
# Base Stage
#
FROM php:8.2-fpm-alpine AS base

# Update packages to fix potential vulnerabilities
RUN apk upgrade --no-cache

# Metadata container
LABEL maintainer="cesaralejo@gmail.com" \
    version="1.1.0" \
    description="Laravel: PHP-FPM, PostgreSQL, LDAP and SMTP"

# Install system dependencies
RUN apk add --no-cache \
    # Core utilities
    curl unzip git bash \
    # Build dependencies
    $PHPIZE_DEPS g++ make \
    # PHP extension dependencies
    libzip-dev zip libpng-dev freetype-dev libjpeg-turbo-dev libwebp-dev libxpm-dev \
    oniguruma-dev postgresql-dev libxml2-dev zlib-dev icu-dev openldap-dev \
    # Timezone and mail
    tzdata msmtp ca-certificates \
    # Monitoring
    htop procps

# Configure timezone to America/Bogota
RUN ln -sf /usr/share/zoneinfo/America/Bogota /etc/localtime && \
    echo "America/Bogota" > /etc/timezone

# Configure and install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp --with-xpm && \
    docker-php-ext-install -j$(nproc) \
    pdo pdo_pgsql pgsql gd zip opcache mbstring exif fileinfo bcmath dom intl ldap

# Config PHP by production
RUN { \
        echo 'opcache.enable=1'; \
        echo 'opcache.memory_consumption=256'; \
        echo 'opcache.interned_strings_buffer=16'; \
        echo 'opcache.max_accelerated_files=10000'; \
        echo 'opcache.revalidate_freq=2'; \
        echo 'opcache.validate_timestamps=0'; \
        echo 'opcache.save_comments=0'; \
        echo 'opcache.fast_shutdown=1'; \
        echo 'realpath_cache_size=4096K'; \
        echo 'realpath_cache_ttl=600'; \
        echo 'memory_limit=512M'; \
        echo 'max_execution_time=60'; \
        echo 'max_input_vars=3000'; \
        echo 'post_max_size=100M'; \
        echo 'upload_max_filesize=100M'; \
        echo 'date.timezone=America/Bogota'; \
        echo 'expose_php=Off'; \
    } > /usr/local/etc/php/conf.d/99-production.ini

#
# Composer Stage
#
FROM composer:2.8.11 AS composer_stage

#
# Dependencies Stage
#
FROM base AS dependencies

WORKDIR /app

# Copy composer files and install dependencies
COPY --from=composer_stage /usr/bin/composer /usr/local/bin/composer
COPY src/composer.json src/composer.lock ./
RUN composer install \
        --no-dev \
        --no-interaction \
        --optimize-autoloader \
        --no-scripts \
        --prefer-dist \
        --no-progress \
    && composer clear-cache

#
# Production Stage
#
FROM php:8.2-fpm-alpine AS production

# Update packages to fix potential vulnerabilities
RUN apk upgrade --no-cache

WORKDIR /var/www/html

# Install only dependencies runtime (sin herramientas de desarrollo)
RUN apk add --no-cache \
    libzip libpng freetype libjpeg-turbo libwebp libxpm \
    oniguruma postgresql-libs libxml2 zlib icu-libs \
    openldap msmtp ca-certificates tzdata

# Config timezone
RUN ln -sf /usr/share/zoneinfo/America/Bogota /etc/localtime && \
    echo "America/Bogota" > /etc/timezone

# Copy installed extensions from base stage
COPY --from=base /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=base /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# CopY dependencies from Composer
COPY --from=dependencies /app/vendor/ ./vendor/

# Copy application code
COPY src/ .

# Create folders and set proper permissions for Laravel
RUN mkdir -p \
        storage/app/public \
        storage/framework/sessions \
        storage/framework/views \
        storage/framework/cache \
        storage/logs \
        bootstrap/cache \
        public/uploads && \
    chown -R www-data:www-data \
        /var/www/html/storage \
        /var/www/html/bootstrap/cache \
        /var/www/html/public/uploads && \
    chmod -R 775 \
        /var/www/html/storage \
        /var/www/html/bootstrap/cache \
        /var/www/html/public/uploads

# Configure optimized PHP-FPM
RUN { \
        echo '[www]'; \
        echo 'user = www-data'; \
        echo 'group = www-data'; \
        echo 'listen = 9000'; \
        echo 'listen.owner = www-data'; \
        echo 'listen.group = www-data'; \
        echo 'listen.mode = 0660'; \
        echo 'pm = dynamic'; \
        echo 'pm.max_children = 50'; \
        echo 'pm.start_servers = 10'; \
        echo 'pm.min_spare_servers = 5'; \
        echo 'pm.max_spare_servers = 35'; \
        echo 'pm.max_requests = 1000'; \
        echo 'pm.process_idle_timeout = 10s'; \
        echo 'pm.status_path = /fpm-status'; \
        echo 'ping.path = /fpm-ping'; \
        echo 'access.log = /proc/self/fd/2'; \
        echo 'catch_workers_output = yes'; \
        echo 'decorate_workers_output = no'; \
        echo 'clear_env = no'; \
        echo 'request_terminate_timeout = 120s'; \
        echo 'rlimit_files = 1024'; \
        echo 'rlimit_core = 0'; \
    } > /usr/local/etc/php-fpm.d/zz-production.conf

# Optimization Laravel in ejecution time
RUN php artisan config:cache --no-interaction && \
    php artisan route:cache --no-interaction && \
    php artisan view:cache --no-interaction && \
    php artisan event:cache --no-interaction || true

# Switch to non-root user
USER www-data

# Expose port
EXPOSE 9000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD SCRIPT_NAME=/fpm-ping SCRIPT_FILENAME=/fpm-ping REQUEST_METHOD=GET \
        cgi-fcgi -bind -connect 127.0.0.1:9000 || exit 1

# Variables de entorno por defecto
ENV APP_ENV=production \
    APP_DEBUG=false \
    LOG_CHANNEL=stderr \
    SESSION_DRIVER=file \
    CACHE_DRIVER=file

# Start PHP-FPM
CMD ["php-fpm"]
