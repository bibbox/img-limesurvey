## BBv4 Version
FROM php:7.4-apache
ARG limesurvey_version='5.6.0+230116'
ARG sha256_checksum='5cc879f3cf8aa8e6f6cab4f5a460e1c386de0e9e002caf969688442870d0f9a4'

# install the PHP extensions we need
RUN apt-get update && apt-get install -y unzip libc-client-dev libfreetype6-dev libmcrypt-dev libpng-dev libjpeg-dev libldap2-dev zlib1g-dev libkrb5-dev libtidy-dev libzip-dev libsodium-dev && rm -rf /var/lib/apt/lists/* \
	&& docker-php-ext-configure gd --with-freetype=/usr/include/  --with-jpeg=/usr \
	&& docker-php-ext-install gd mysqli pdo pdo_mysql opcache zip iconv tidy \
    && docker-php-ext-configure ldap --with-libdir=lib/$(gcc -dumpmachine)/ \
    && docker-php-ext-install ldap \
    && docker-php-ext-configure imap --with-imap-ssl --with-kerberos \
    && docker-php-ext-install imap \
    && docker-php-ext-install sodium \
    && pecl install mcrypt-1.0.3 \
    && docker-php-ext-enable mcrypt \
    && docker-php-ext-install exif

RUN a2enmod rewrite

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
		echo 'opcache.enable_cli=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

# Download, unzip and chmod LimeSurvey from official source
RUN set -x; \
    curl -sSL "https://download.limesurvey.org/latest-stable-release/limesurvey${limesurvey_version}.zip" -o /tmp/lime.zip; \
    echo "${sha256_checksum} /tmp/lime.zip" | sha256sum -c -; \
    unzip /tmp/lime.zip -d /tmp; \
    mv /tmp/lime*/* /var/www/html/; \
    mv /tmp/lime*/.[a-zA-Z]* /var/www/html/; \
    rm /tmp/lime.zip; \
    rmdir /tmp/lime*; \
    chown -R www-data:www-data /var/www/html; \
    mkdir -p /var/lime/application/config; \
    mkdir -p /var/lime/upload; \
    mkdir -p /var/lime/plugins; \
    cp -dpR /var/www/html/application/config/* /var/lime/application/config; \
    cp -dpR /var/www/html/upload/* /var/lime/upload; \
    cp -dpR /var/www/html/plugins/* /var/lime/plugins

#Set PHP defaults for Limesurvey (allow bigger uploads)
RUN { \
        echo 'memory_limit=256M'; \
        echo 'upload_max_filesize=128M'; \
        echo 'post_max_size=128M'; \
        echo 'max_execution_time=120'; \
        echo 'max_input_vars=10000'; \
        echo 'date.timezone=UTC'; \
	} > /usr/local/etc/php/conf.d/uploads.ini

VOLUME ["/var/www/html/plugins"]
VOLUME ["/var/www/html/upload"]

#ensure that the config is persisted especially for security.php
VOLUME ["/var/www/html/application/config"]



COPY entrypoint.sh /var/www/html/entrypoint.sh
RUN ["chmod", "+x", "/var/www/html/entrypoint.sh"]
ENTRYPOINT [ "/var/www/html/entrypoint.sh" ]
CMD ["apache2-foreground"]
