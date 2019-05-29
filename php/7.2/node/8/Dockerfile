FROM php:7.2-apache

ENV APACHE_DOCUMENT_ROOT /var/www/web
ENV NODE_MAJOR_VERSION 8

ENV PATH="/var/www/node_modules/.bin:/var/www/vendor/bin:/var/www/bin:${PATH}"

# Install dependencies
RUN set -ex; \
  \
  mkdir -p /usr/share/man/man1 /usr/share/man/man7; \
  \
  if command -v a2enmod; then \
    a2enmod rewrite; \
  fi; \
  \
  savedAptMark="$(apt-mark showmanual)"; \
  \
  # install the installation dependencies we need
  apt-get update; \
  apt-get install -y --no-install-recommends \
    bc \
    gnupg \
    libjpeg-dev \
    libpng-dev \
    libpq-dev \
    libzip-dev \
  ; \
  \
  # install the PHP extensions we need
  docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr; \
  docker-php-ext-install -j "$(nproc)" \
    bcmath \
    gd \
    opcache \
    pdo_mysql \
    pdo_pgsql \
    zip \
  ; \
  \
  # reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
  apt-mark auto '.*' > /dev/null; \
  apt-mark manual $savedAptMark; \
  ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
    | awk '/=>/ { print $3 }' \
    | sort -u \
    | xargs -r dpkg-query -S \
    | cut -d: -f1 \
    | sort -u \
    | xargs -rt apt-mark manual; \
  \
  # add node related repositories
  if [ "$NODE_MAJOR_VERSION" != "false" ]; then \
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - ; \
    echo "deb http://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list; \
    \
    curl -sL https://deb.nodesource.com/setup_${NODE_MAJOR_VERSION}.x | bash - ; \
  fi; \
  \
  # update list of packages
  apt-get update; \
  \
  # install php running dependencies
  apt-get install -y --no-install-recommends \
    git \
    imagemagick \
    libpng-dev \
    mysql-client \
    netcat \
    sudo \
    unzip \
    vim \
    webp \
  ; \
  \
  # install node related dependencies
  if [ "$NODE_MAJOR_VERSION" != "false" ]; then \
    apt-get install -y --no-install-recommends \
      nodejs \
      python2.7 \
      yarn \
    ; \
    \
    npm config set --global python python2.7; \
    npm install -g bower; \
  fi; \
  \
  # Install faketime
  # See https://github.com/wolfcw/libfaketime
  git clone https://github.com/wolfcw/libfaketime.git /usr/src/faketime; \
  ( \
    cd /usr/src/faketime; \
    make install; \
  ); \
  rm -rf /usr/src/faketime; \
  \
  # cleanup
  apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
  rm -rf /var/lib/apt/lists/*

# setup apache
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
# revalidate_freq is set to 0 to avoid delay in development mode.
RUN { \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=4000'; \
    echo 'opcache.revalidate_freq=0'; \
    echo 'opcache.fast_shutdown=1'; \
    echo 'opcache.enable_cli=1'; \
  } > /usr/local/etc/php/conf.d/opcache-recommended.ini

# Set PHP settings for Docker
ENV PHP_MEMORY_LIMIT="256M"
RUN { \
    echo 'date.timezone="Europe/Zurich"'; \
    echo 'memory_limit=${PHP_MEMORY_LIMIT}'; \
  } > /usr/local/etc/php/conf.d/docker.ini

# install Composer.
RUN curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer

# install custom scripts
COPY ./scripts/wait-for-it ./scripts/docker-as-* /usr/local/bin/
RUN chmod 755 /usr/local/bin/docker-as-* /usr/local/bin/wait-for-it

# set workdir and volume
RUN rm -rf /var/www/*
WORKDIR /var/www

# volumes
VOLUME /var/backups

CMD ["apache2-foreground"]
