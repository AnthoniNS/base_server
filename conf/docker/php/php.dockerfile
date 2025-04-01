# Defina a variável de ambiente para o ambiente desejado
ARG ENVIRONMENT

# Imagem base com PHP e FrankenPHP
FROM dunglas/frankenphp:1.1.5-php8.3-alpine as base

# Instalar extensões do PHP e dependências necessárias
RUN curl -L -o /tmp/redis.tar.gz https://github.com/phpredis/phpredis/archive/6.0.2.tar.gz \
    && mkdir -p /usr/src/php/ext/redis \
    && tar xfz /tmp/redis.tar.gz --directory /usr/src/php/ext/redis \
    && rm -r /tmp/redis.tar.gz \
    && apk add --no-cache \
         curl-dev \
         git \
         icu-dev \
         libxml2-dev \
         libzip-dev \
         libpng-dev \
         oniguruma-dev \
         linux-headers \
         autoconf \
         g++ \
         make \
         nss-tools \
         gnupg \
    # Instala a chave e o glibc (necessário para rodar o mkcert compilado com glibc)
    && curl -Lo /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub \
    && curl -Lo /tmp/glibc.apk https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r0/glibc-2.35-r0.apk \
    && apk add --no-cache --force-overwrite /tmp/glibc.apk \
    && rm /tmp/glibc.apk \
    # Baixa e instala o mkcert usando o asset correto para Linux
    && curl -L -o /usr/local/bin/mkcert https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-v1.4.4-linux-amd64 \
    && chmod +x /usr/local/bin/mkcert \
    && mkcert -install \
    && docker-php-ext-install -j$(nproc) \
         bcmath \
         curl \
         intl \
         mbstring \
         pcntl \
         pdo \
         pdo_mysql \
         xml \
         zip \
         gd \
         sockets \
         exif \
    # Baixa e configura o cacert.pem
    && curl -o /etc/ssl/certs/cacert.pem https://curl.se/ca/cacert.pem \
    && echo "curl.cainfo = /etc/ssl/certs/cacert.pem" >> /usr/local/etc/php/conf.d/cacert.ini \
    && echo "openssl.cafile = /etc/ssl/certs/cacert.pem" >> /usr/local/etc/php/conf.d/cacert.ini

# Instala Stripe CLI diretamente via binário
RUN curl -L https://github.com/stripe/stripe-cli/releases/latest/download/stripe_linux_x86_64 \
    -o /usr/local/bin/stripe \
    && chmod +x /usr/local/bin/stripe

# Instalar o Composer
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer
COPY ./www/app /srv

COPY ./conf/traefik /srv/traefik
# Instalar uma alternativa ao CRON adequada para containers
RUN wget -q "https://github.com/aptible/supercronic/releases/download/v0.2.29/supercronic-linux-amd64" \
         -O /usr/bin/supercronic \
    && chmod +x /usr/bin/supercronic

# Definir o usuário como root para operações subsequentes
USER root

# Copiar arquivos de configuração específicos para o ambiente
FROM base as development
RUN mv /usr/local/etc/php/php.ini-development /usr/local/etc/php/conf.d/php.ini-development
COPY ./conf/docker/php/config/php-config.development.ini /usr/local/etc/php/conf.d/php-config.development.ini

FROM base as production
RUN mv /usr/local/etc/php/php.ini-production /usr/local/etc/php/conf.d/php.ini-production
COPY ./conf/docker/php/config/php-config.production.ini /usr/local/etc/php/conf.d/php-config.production.ini

# Selecionar o ambiente de construção
FROM ${ENVIRONMENT}

# Copiar o arquivo de configuração do Caddy
COPY ./conf/docker/php/config/Caddyfile /etc/caddy/Caddyfile

# Definir o diretório de trabalho
WORKDIR /srv

USER root

# Install PHPStan
RUN composer global require phpstan/phpstan

# Garantir que os diretórios 'storage' e 'vendor' tenham as permissões desejadas
RUN mkdir -p /srv/storage/logs \
    && touch /srv/storage/logs/laravel.log \
    && chmod -R 775 /srv/storage/logs/laravel.log \
    && chown -R root:root /srv/storage \
    && chmod -R 775 /srv/storage \
    && mkdir -p /srv/vendor \
    && chown -R root:root /srv/vendor \
    && chmod -R 777 /srv/vendor \
    && chmod -R 775 /srv/traefik
    
RUN chmod -R 777 /srv/vendor
RUN composer install
RUN php artisan key:generate \
    && php artisan config:clear \
    && php artisan route:cache && php artisan view:cache


RUN mkcert -install -cert-file /srv/traefik/tls/cert.pem -key-file /srv/traefik/tls/key.pem "*.app.localhost" app.localhost