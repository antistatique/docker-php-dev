# Docker image for PHP+Node development

## Setup

A `docker-compose.yml` file must be created in project working directory. Follow setup related to
the project type. This image support any PHP/Node project and have an apache server running and
rendering content in the working diretory. Folling type of project have a dedicted helper tool:

* Drupal (`docker-as-drupal`)

The volume `/var/www` can have a delay before updates made on the host are visible in the
container ; remove `:cached` if it's an issue but that will result to slowest command
execution time in docker

### PHP & Node versions

The version for PHP and Node can be selected in image tag, follwing versions are availables :

* PHP 7.1
  * Node 8
  * Node 9
  * Node 10
  * Node 11
* PHP 7.2
  * Node 8
  * Node 9
  * Node 10
  * Node 11
* PHP 7.3
  * Node 11
  * Node 11

### Drupal setup

This setup using _Mailcatcher_ as mail server, and mysql as database (remove mail service if
not required).

Following environement variable are available:

```bash
DATABASE_URL     # Database URL scheme, should be different for dev and test services
DATABASE_DUMP    # Database dump file path (default to "/var/backups/database.sql"). Must
                 # be located in a volume shared by dev and test services.
SMTP_HOST        # <host:port> to mail server (docker mailcatcher service)
SITE_NAME        # Default set to "Drupal Website"
SITE_UUID        # Deault set to UUID in system.side.yml file
PRIVATE_FILES    # Path to private files diretory (add it to settings on bootstrap)
DEFAULT_CONTENT  # Default content modules to use
```

`behat.yml` file must have a docker profile and MailCatcher webmail url can be setup like
in follwing example if used:

```yaml
docker:
  extensions:
    Alex\MailCatcher\Behat\MailCatcherExtension\Extension:
      url: http://mail:1080
```

`docker-compose.yml`:

```yaml
version: '3.6'

services:
  # Drupal development server
  dev:
    image: antistatique/php-dev:7.1-node8
    ports:
      - "8080:80"
    depends_on:
      - db
      - mail
    environment:
      DATABASE_URL: mysql://drupal:drupal@db/drupal_development
      SMTP_HOST: mail:1025
      PRIVATE_FILES: /var/private_files
      DEFAULT_CONTENT: project_default_content
    restart: always
    volumes:
      - .:/var/www:cached
      - backups:/var/backups

  # Drupal test server
  test:
    image: antistatique/php-dev:7.1-node8
    command: docker-as-drupal runserver 0.0.0.0:8888
    ports:
      - "8888:8888"
    depends_on:
      - db
      - mail
    environment:
      DATABASE_URL: mysql://drupal:drupal@db/drupal_test
      SMTP_HOST: mail:1025
      PRIVATE_FILES: /var/private_files
      DEFAULT_CONTENT: project_default_content
    restart: "no"
    volumes:
      - .:/var/www:cached
      - backups:/var/backups

  # Database
  db:
    image: mariadb:10.1
    environment:
      MYSQL_USER: drupal
      MYSQL_PASSWORD: drupal
      MYSQL_DATABASE: drupal\_%
      MYSQL_ROOT_PASSWORD: root
    restart: always
    volumes:
      - database:/var/lib/mysql

  # Mail
  mail:
    image: schickling/mailcatcher
    ports:
      - "1025:1025"
      - "1080:1080"
    restart: always

volumes:
  database:
  backups:
```

Use `docker-compose up` to start services then following command to boostrap (or reset) the
Drupal installation: `docker-compose exec dev docker-as-drupal bootstrap`. Test service must
be started manualy after bootstrap by running `docker-compose restart test`.


### Custom docker image

To install more packages or change some setup in docker image, a local `Dockerfile` can  be created
and the `docker-compose.yml` file must be updated to use _build_ instead of _image_ config.
`Dockerfile` _FROM_ tag must be set properly, refer to comment in following file example for more
information about how to install a package or enable PHP extension.

```yaml
services:
  dev:
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

`docker-compose` use directory name as default project name to prefix container and volume
name, that can be overrided with `-p <name>` options in case of conflict.

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

# Run the commmand in existing service container
docker-compose exec <service name> <comand>
```

### Drupal


`docker-as-drupal` script is used to manage database, Drupal install or run behat.

*bootstrap* must be run to setup Drupal project, that will install dependencies, install
Drupal, setup database and all required settings. A database dump is also created before
loading default content to be used to setup test environment (or reseet default content
later).

Available options are:

```bash
docker-compose exec web docker-as-drupal bootstrap [options]

  --skip-dependencies      # Do not run composer and yarn install
  --skip-install           # Do not run Drupal install (only if arealdy installed)
  --skip-default-content   # Do not load default content
  --skip-styleguide-build  # Do not run yarn build
```

*db-reset* reset database using database dump made by last bootstrap command or _db-reset_
command.

Available options are:

```bash
docker-compose exec web docker-as-drupal db-reset [options]

  --skip-default-content   # Do not load default content
  --update-dump            # Update database dump (include updated Drupal config)
```

*behat* setup database and settings properly then run behat command including any options
like file path, _--rerun_ or more.

Available options are:

```bash
docker-compose exec test docker-as-drupal behat [options]

  --skip-reset             # Skip database reset before default content reload
```


## Work on the docker image

```bash
./update.sh
./update.sh --build=<7.2-node9|all|latest>
./update.sh --publish==<7.2-node9|all|latest>
```
