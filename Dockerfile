## BBv4 Version
FROM php:8-apache
ARG version='5.0.9+210722'
ARG sha256_checksum='2d9bc1ba0874f462bac6c94cad16127d0d231e0a257d8e895578354d28a84812'

# Install OS dependencies
RUN set -ex; \
        apt-get update && \
        DEBIAN_FRONTEND=noninteractive \
        apt-get install --no-install-recommends -y \
        \
        libldap2-dev \
        libfreetype6-dev \
        libjpeg-dev \
        libonig-dev \
        zlib1g-dev \
        libc-client-dev \
        libkrb5-dev \
        libpng-dev \
        libpq-dev \
        libzip-dev \
        libtidy-dev \
        libsodium-dev \
        netcat \
        curl \
        \
        && apt-get -y autoclean; apt-get -y autoremove; \
        rm -rf /var/lib/apt/lists/*

# Link LDAP library for PHP ldap extension
RUN set -ex; \
        ln -fs /usr/lib/x86_64-linux-gnu/libldap.so /usr/lib/

# Install PHP Plugins and Configure PHP imap plugin
RUN set -ex; \
        docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr && \
        docker-php-ext-configure imap --with-kerberos --with-imap-ssl && \
        docker-php-ext-install -j5 \
        exif \
        gd \
        imap \
        ldap \
        mbstring \
        pdo \
        pdo_mysql \
        pdo_pgsql \
        pgsql \
        sodium \
        tidy \
        zip

ENV LIMESURVEY_VERSION=$version

# Apache configuration
RUN a2enmod headers rewrite remoteip; \
        {\
        echo RemoteIPHeader X-Real-IP ;\
        echo RemoteIPTrustedProxy 10.0.0.0/8 ;\
        echo RemoteIPTrustedProxy 172.16.0.0/12 ;\
        echo RemoteIPTrustedProxy 192.168.0.0/16 ;\
        } > /etc/apache2/conf-available/remoteip.conf;\
        a2enconf remoteip

# Use the default production configuration
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Download, unzip and chmod LimeSurvey from official GitHub repository
RUN set -ex; \
        curl -sSL "https://github.com/LimeSurvey/LimeSurvey/archive/${version}.tar.gz" --output /tmp/${version}.tar.gz && \
        echo "${sha256_checksum}  /tmp/${version}.tar.gz" | sha256sum -c - && \
        \
        tar xzvf "/tmp/${version}.tar.gz" --strip-components=1 -C /var/www/html/ && \
        rm -f "/tmp/${version}.tar.gz" && \
        chown -R www-data:www-data /var/www/html /etc/apache2


WORKDIR /var/www/html
COPY entrypoint.sh /var/www/html/entrypoint.sh

# ENTRYPOINT ["sh", "/var/www/html/entrypoint.sh"]

CMD ["bash", "/var/www/html/entrypoint.sh"]

# CMD ["apache2-foreground"]
