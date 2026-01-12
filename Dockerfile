############################################
# STAGE 1 — BUILD
############################################
FROM unit:1.34.1-php8.3 AS build

ARG APP_ENV=build
ENV APP_ENV=build
ENV APP_DEBUG=false

RUN apt update && apt install -y \
    curl unzip git libicu-dev libzip-dev libpng-dev libjpeg-dev libfreetype6-dev libssl-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pcntl opcache pdo pdo_mysql intl zip gd exif ftp bcmath \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apt clean && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

WORKDIR /var/www/html

# ⬇⬇⬇ COPY APP FIRST (THIS FIXES THE ERROR)
COPY . .

# Ensure Laravel dirs exist
RUN mkdir -p storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# Now composer can see artisan
RUN composer install \
    --prefer-dist \
    --optimize-autoloader \
    --no-interaction \
    --no-progress

############################################
# STAGE 2 — RUNTIME
############################################
FROM unit:1.34.1-php8.3

WORKDIR /var/www/html

RUN echo "opcache.enable=1" > /usr/local/etc/php/conf.d/custom.ini \
    && echo "opcache.jit=tracing" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "opcache.jit_buffer_size=256M" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "memory_limit=512M" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "upload_max_filesize=64M" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "post_max_size=64M" >> /usr/local/etc/php/conf.d/custom.ini

COPY --from=build /var/www/html /var/www/html

COPY unit.json /docker-entrypoint.d/unit.json

EXPOSE 8000
CMD ["unitd", "--no-daemon"]
