FROM php:7.0-fpm

# install additinal packages and PHP extensions
RUN apt-get update && apt-get install -y \
        unzip \
        git \
        libmcrypt-dev \
        zlib1g-dev \
        libicu-dev \
        g++ \
        sudo \
    && docker-php-ext-configure intl \
    && docker-php-ext-install -j$(nproc) intl \
    && docker-php-ext-install -j$(nproc) mcrypt \
    && docker-php-ext-install -j$(nproc) pdo_mysql

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.revalidate_freq=60'; \
        echo 'opcache.fast_shutdown=1'; \
        echo 'opcache.enable_cli=1'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini

RUN { \
        echo 'date.timezone = Europe/Berlin'; \
    } > /usr/local/etc/php/conf.d/commsy.ini

# install node
RUN curl -sL https://deb.nodesource.com/setup_6.x | bash - \
    && apt-get install nodejs -yqq

# install global Node.js packages
RUN npm -g install bower gulp

VOLUME /var/www/html

ENV COMMSY_COMMIT_SHA 18ba68ecac21d341cf56f5402be08277ee5baa9d

# download commsy
# RUN curl -o commsy.zip -SL https://github.com/commsy/commsy/releases/download/v9.0.0-alpha.1/commsy_v9.0.0-alpha.1.zip \
#         && unzip commsy.zip -d /var/www/html \
#         && rm commsy.zip \
#         && chown -R www-data:www-data /var/www/html

RUN curl -o commsy.zip -SL https://github.com/commsy/commsy/archive/${COMMSY_COMMIT_SHA}.zip \
        && unzip commsy.zip -d /usr/src/commsy \
        && rm commsy.zip \
        && mv /usr/src/commsy/commsy-${COMMSY_COMMIT_SHA}/* /usr/src/commsy/ \
        && rm -r /usr/src/commsy/commsy-${COMMSY_COMMIT_SHA} \
        && chown -R www-data:www-data /usr/src/commsy


# RUN cd /usr/src/ \
#         && git clone https://github.com/commsy/commsy.git -n commsy \
#         && cd commsy \
#         && git checkout -b 9.0 ${COMMSY_COMMIT_SHA} \
#         && mv /usr/src/commsy/* /var/www/html \
#         && rm -r /usr/src/commsy \
#         && chown -R www-data:www-data /var/www/html

COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod u+x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm"]

#COPY docker-entrypoint.sh /entrypoint.sh

#ENTRYPOINT ["/entrypoint.sh"]

#CMD ["php-fpm"]