# Docker image for PHP+Node development

## Setup

Create file `docker-compose.yml` in project root directory using following content. PHP, Node and
MySQL version must be set properly.

```yaml
version: '3.6'

services:
  # Web server
  web:
    image: antistatique/php-dev:7.2-node11
    ports:
      - "8080:80"
      - "3000:3000"
      - "3001:3001"
    depends_on:
      - db
    restart: always
    volumes:
      - .:/var/www:delegated

  # Database
  db:
    image: mysql:5.7.23
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: drupal
      MYSQL_USER: drupal
      MYSQL_PASSWORD: drupal
    restart: always
    volumes:
      - database:/var/lib/mysql

volumes:
  database:
```

To install more packages or change some setup in docker image, a local `Dockerfile` can  be created
and the `docker-compose.yml` file must be updated to use _build_ instead of _image_ config.
`Dockerfile` _FROM_ tag must be set properly, refer to comment in following file example for more
information about how to install a package or enable PHP extension.

```yaml

services:
  web:
    build: .

```

```Dockerfile
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

```

## Usage

Start services with `docker-compose up`, _CTRL+C_ to stop them. `--build` option can be use when
a custom `Dockerfile` exists to force to re-build the image.

`docker-compose` use directory name as default project name as prefix for container and storage
name, that can be overrided with `-p <name>` options in case of conflict options in case of
conflict.

### Managing docker

```bash
docker-compose up             # Start services (CTRL+C to stop)
docker-compose up --build     # Start services and force build of local Dockerfile if exists
docker-compose pull           # Pull remote images (to update them)

docker-compose down           # Remove containers and network interfaces (do not remove db storage)
docker-compose rm             # Remove all stopped service containers

docker system prune           # Remove unused data (dandling images, stopped containers, unused
                              # networks and build caches)
docker system prune --all     # Remove all images, containers and networks
docker volume ls              # list all existing volums (on computer)
docker volume rm <volume>     # Remove named volume (to reset database)
```

### Managing project

```bash

docker-compose run --rm web <comand>    # Spawn new service container to run the command
                                        # (container is removed when existing)
docker-compose exec web <comand>        # Run the commmand in existing service container

docker-compose exec web docker-as-cleanup

docker-compose exec web docker-as-deps
docker-compose exec web docker-as-drupal-init
docker-compose exec web docker-as-styles-build

docker-compose exec web docker-as-drupal-prepare

docker-compose exec web docker-as-styles-serve
```


## Update

```bash
./update.sh
./update.sh --build=<7.2-node9|all|latest>
./update.sh --publish==<7.2-node9|all|latest>
```
