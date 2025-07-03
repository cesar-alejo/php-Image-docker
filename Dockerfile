FROM php:8.2-fpm-alpine

LABEL maintainer="cesaralejo@gmail.com"
LABEL version="1.0.2"
LABEL description="PHP-FPM: Composer, Laravel, PostgreSQL, LDAP y SMTP"

# Install system dependencies
RUN apk add --no-cache \
    # Core utilities
    curl \
    unzip \
    git \
    bash \
    # Build dependencies
    g++ \
    make \
    # PHP extension dependencies
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
    openldap-dev \
    # Timezone and mail
    tzdata \
    msmtp

# Configure timezone to America/Bogota
RUN cp /usr/share/zoneinfo/America/Bogota /etc/localtime \
    && echo "America/Bogota" > /etc/timezone

# Configure GD extension with support for various image formats
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp \
    --with-xpm

# Install PHP extensions
RUN docker-php-ext-install -j$(nproc) \
    # Database extensions
    pdo \
    pdo_pgsql \
    pgsql \
    # Image processing
    gd \
    # Archive and compression
    zip \
    # Performance
    opcache \
    # String processing
    mbstring \
    # File handling
    exif \
    fileinfo \
    # Math and calculations
    bcmath \
    # XML processing
    dom \
    # Internationalization
    intl \
    # LDAP authentication
    ldap

# Install Composer globally
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer
    
# Set working directory
WORKDIR /var/www/html

# Copy application code
COPY ./src .
    
# Install Composer dependencies
# --no-dev: Excluye las dependencias de desarrollo.
# --no-interaction: No pide entrada interactiva.
# --optimize-autoloader: Genera un autoloader optimizado para producción.
# --prefer-dist: Descarga paquetes desde sus archivos distribuidos cuando sea posible.
RUN composer install \
    --no-dev \
    --no-interaction \
    --optimize-autoloader \
    --prefer-dist \
    --no-scripts    

# Set proper permissions for Laravel
RUN chown -R www-data:www-data \
    /var/www/html/storage \
    /var/www/html/bootstrap/cache \
    /var/www/html/upload \
    && chmod -R 775 \
    /var/www/html/storage \
    /var/www/html/bootstrap/cache \
    /var/www/html/upload

# Create PHP-FPM configuration
RUN echo "pm.max_children = 50" >> /usr/local/etc/php-fpm.d/www.conf \
    && echo "pm.start_servers = 5" >> /usr/local/etc/php-fpm.d/www.conf \
    && echo "pm.min_spare_servers = 5" >> /usr/local/etc/php-fpm.d/www.conf \
    && echo "pm.max_spare_servers = 35" >> /usr/local/etc/php-fpm.d/www.conf

# Expose port 9000
EXPOSE 9000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD php -v || exit 1

# Start PHP-FPM
CMD ["php-fpm"]
