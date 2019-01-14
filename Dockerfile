FROM antistatique/php-dev:7.2-node11

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
  # apt-get install -y --no-install-recommends \
  #  libjpeg-dev \
  #  libpng-dev \
  #  libpq-dev \
  #  libzip-dev \
  #  gnupg \
  #; \
  \
  # install the PHP extensions we need
  # docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr; \
  # docker-php-ext-install -j "$(nproc)" \
  #   gd \
  #   opcache \
  #   pdo_mysql \
  #   pdo_pgsql \
  #   zip \
  # ; \
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
  # install running dependencies (custom sources can be add here)
  # curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - ; \
  # echo "deb http://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list; \
  \
  apt-get update; \
  # apt-get install -y --no-install-recommends \
  #   unzip \
  # ; \
  \
  apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
  rm -rf /var/lib/apt/lists/*

# Add local setup here
