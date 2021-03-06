# Docker image for PHP+Node development

![GH Workflow Status](https://github.com/antistatique/docker-php-dev/workflows/.github/workflows/ci.yml/badge.svg)

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

* PHP 5.6
  * Node 8
* PHP 7.0
  * Node 8
  * Node 10
* PHP 7.1
  * Node 6
  * Node 8
  * Node 9
  * Node 10
  * Node 11
  * Node 12
* PHP 7.2
  * Node 8
  * Node 9
  * Node 10
  * Node 11
  * Node 12
* PHP 7.3
  * Node 10
  * Node 11
  * Node 12
* PHP 7.4
  * Node 10
  * Node 11
  * Node 12
 * PHP 8.0
  * Node 12
  * Node 14

### Drupal setup

This setup using _Mailcatcher_ as mail server, and mysql as database (remove mail service if
not required).

Following environement variable are available:

```bash
APACHE_DOCUMENT_ROOT          # Apache Document Root (default to "/var/www/web")
PHP_MEMORY_LIMIT              # Set PHP mermory limit (default to "256M")

APP_ENV                       # Eq: development, test, production. This environment variable
                              # is used to load specific settings per environment.

DATABASE_URL                  # Database URL scheme, should be different for dev and test services
DATABASE_DUMP                 # Database dump file path (default to "/var/backups/db-reset.sql"). Must
                              # be located in a volume shared by dev and test services.
SMTP_HOST                     # <host:port> to mail server (default to mail:1025 as docker mailcatcher service)
SITE_NAME                     # Drupal site name (default set to "Drupal Website")
SITE_CONFIG_DIR               # Drupal configuration sync directory (default to /var/www/config/d8/sync)
SITE_UUID                     # Drupal site UUID (default set to UUID in system.side.yml file)
SITE_HASH_SALT                # Drupal hash salt (default to random string)
SITE_INSTALL_PROFILE          # Drupal installation profile (default to standard)
PRIVATE_FILES                 # Path to private files diretory (add it to settings on bootstrap)
DEFAULT_CONTENT               # Default content modules to use
LOG_DIR                       # Default to /var/www/log (behat and phpunit output directories are inside)
REQUIRED_DIRECTORIES          # List of directories to create (separate by space)
DRUPAL_CONFIG_SET             # Configurations keys to be overriden

BEHAT_PROFILE                 # Behat config profile (default to "default")
PHPUNIT_DEFAULT_GROUP         # Default phpunit group used if "--group" is not set
SIMPLETEST_BASE_URL           # Default to "http://test:8888"
SIMPLETEST_DB                 # Default to DATABASE_URL, can be overwrited
SYMFONY_DEPRECATIONS_HELPER   # Default to weak, can be overwrited
TEST_SERVER_PORT              # Default to 8888
CONFIG_IMPORT_ATTEMPTS        # Number of attemps to run config:import (default to 5)

DISABLE_DEVELOPMENT           # Set to disable development mode (that means we skip some restore
                              # steps after running tests or other stuff like that. Use for one
                              # time running container)
LOCK_TIME                     # Lock time on running server and when run tests. Use format "2018-12-24 12:24:00"
                              # See https://github.com/wolfcw/libfaketime for more information
TEST_ENABLE_MODULES           # Modules to enable when running tests, separate by space
TEST_DISABLE_MODULES          # Modules to disable when running tests, separate by space (default: big_pipe)
TEST_USER                     # Set a default user to run tests
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
      APP_ENV: development
      DATABASE_URL: mysql://drupal:drupal@db/drupal_development
      PRIVATE_FILES: /var/www/web/sites/default/files/private
      DEFAULT_CONTENT: project_default_content
    restart: always
    volumes:
      - .:/var/www:cached
      - backups:/var/backups

  # Drupal test server
  test:
    image: antistatique/php-dev:7.1-node8
    command: docker-as-wait --mysql -- docker-as-drupal apache-server
    ports:
      - "8888:8888"
    depends_on:
      - db
      - mail
    environment:
      APP_ENV: test
      DATABASE_URL: mysql://drupal:drupal@db/drupal_test
      PRIVATE_FILES: /var/www/web/sites/default/files/private
      DEFAULT_CONTENT: project_default_content
    restart: "no"
    volumes:
      - .:/var/www:cached
      - backups:/var/backups

  # Database
  db:
    image: mariadb:10.1
    ports:
      - "3306:3306"
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

**settings.php files**
You can create different PHP settings file based on the `APP_ENV` environment.
The format is `${APP_ENV}.settings.php`:

```
# ./web/sites/default/development.settings.php

$settings['container_yamls'][] = DRUPAL_ROOT . '/sites/development.services.yml';
$config['backerymails.settings']['reroute']['status'] = TRUE;
// ...
```

Finally, a local settings PHP file is loaded if you create the script `./web/sites/default/settings.local.php`.

Use `docker-compose up` to start services then following command to boostrap (or reset) the
Drupal installation: `docker-compose exec dev docker-as-drupal bootstrap`. Test service must
be started manualy after bootstrap by running `docker-compose restart test`.


**DRUPAL_CONFIG_SET**

The Drupal Configurations Override environement variable is kind of special. It may contain 1 or many items te be declared as follow:

Single
```
  DRUPAL_CONFIG_SET: >-
    search_api.server.solr backend_config.connector_config.host solr
```

Multiple
```
  DRUPAL_CONFIG_SET: >-
    search_api.server.solr backend_config.connector_config.host solr;
    search_api.server.solr backend_config.connector_config.core watchdreamer
```

_Note the trailing `;` at the end of each line - excepted on the last one._

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
  # \
  # install xdebug for PHP 7.x
  # if [ $(echo "%%PHP_VERSION%% >= 7.0" | bc -l) -eq 1 ]; then \
  #   pecl install xdebug; \
  #   docker-php-ext-enable \
  #     xdebug \
  #   ; \
  # fi; \
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
docker-compose up -d          # Start services (deamonize)
docker-compose up --build     # Start services and force build of local Dockerfile if exists
docker-compose pull           # Pull remote images (to update them)

docker-compose stop           # Stop services
docker-compose down           # Remove containers and network interfaces (do not remove db storage)
docker-compose rm             # Remove all stopped service containers

docker-compose log            # Display services' log (-f to follow log output)

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
docker-compose exec dev docker-as-drupal bootstrap [options]

  --skip-dependencies      # Do not run composer and yarn install
  --skip-install           # Do not run Drupal install (only if arealdy installed)
  --skip-db-reset          # Do not reset database using SQL dump (only when --skip-install)
  --skip-styleguide-build  # Do not run yarn build
  --with-default-content   # Load default content (force reset database when --skip-install)
  --install-only           # Same ass --skip-dependencies --skip-styleguide-build
```

*setup* ensure that Drupal settings.php file is populated and docker related settings are
properly set. Except install dependencies, same process is done before most of other commands.

```bash
docker-compose exec dev docker-as-drupal setup [options]

  --with-dependencies      # Run composer and yarn install
```

*db-reset* reset database using database dump made by last bootstrap command or _db-reset_
command.

Available options are:

```bash
docker-compose exec dev docker-as-drupal db-reset [options]

  --update-dump            # Update database dump (include updated Drupal config, but not
                           # default content)
  --with-default-content   # Load default content (before dump)
```

*db-dump* dump database. The dump can be used with _db-restore_ to reset database to saved
state.

Available options are:

```bash
docker-compose exec dev docker-as-drupal db-dump [options]

    --file=<path>            # Path to dump file (not required)
```

*db-restore* reset database to saved state using database dump made by last _db-dump_.

Available options are:

```bash
docker-compose exec dev docker-as-drupal db-restore [options]

    --file=<path>            # Path to dump file (not required)
```

*db-update* update database, entities and import config.

*php-server* run `drush runserver $TEST_SERVER_HOST:$TEST_SERVER_PORT` command.

Available options are:

```bash
docker-compose exec test docker-as-drupal php-server [options]

  --with-db-reset          # Reset database before launch server
  --with-default-content   # Load default content (force reset database)
  --help                   # Display runserver help
  -- <...>                 # any runserver valid args
```

*apache-server* run `apache2 -D FOREGROUND -c "DocumentRoot $APACHE_DOCUMENT_ROOT" -c "Listen $TEST_SERVER_PORT"` command.

Available options are:

```bash
docker-compose exec test docker-as-drupal apache-server [options]

  --with-db-reset          # Reset database before launch server
  --with-default-content   # Load default content (force reset database)
  --cache                  # Do not invalidate opcache (server must be restarted
                            # reload cache)
  --help                   # Display apache help
  -- <...>                 # any apache valid args
```

*behat* setup database and settings properly then run behat command including any options
like file path, _--rerun_ or more.

Available options are:

```bash
docker-compose exec test docker-as-drupal behat [options]

  --skip-db-reset          # Do not reset database (to use only if database was reset just before)
  --skip-default-content   # Do not load default content (maybe break the tests, ignored when db is reset)
  --with-dependencies      # Run composer and yarn install
  --help                   # Display behat help
  -- <...>                 # any behat valid args
```

*nightwatch* setup database and settings properly then run nightwatch command. `--group` is required
as Drupal nightwatch tests doesn't pass without more config.

Available options are:

```bash
docker-compose exec test docker-as-drupal nightwatch [options]

  --skip-db-reset          # Do not reset database (to use only if database was reset just before)
  --skip-default-content   # Do not load default content (maybe break the tests, ignored when db is reset)
  --with-dependencies      # Run composer and yarn install
  --group=<group>          # Only runs tests from the specified group(s)
  --help                   # Display behat help
  -- <...>                 # any behat valid args
```

*phpunit* setup database and settings properly then run phpunit command including any options
like file path, _--stop-on-failure_ or more.

Available options are:

```bash
docker-compose exec test docker-as-drupal phpunit [options]

  --skip-db-reset          # Do not reset database (to use only if database was reset just before),
                           # only valid with --skip-db-empty or --with-defaut-content
  --skip-default-stops     # Do not stop on error and failure (remove --stop-on-error --stop-on-failure)
  --with-default-content   # Load default content (force reset database if --skip-db-reset is not used)
  --skip-default-stops     # Do not stop on error and failure (remove --stop-on-error --stop-on-failure)
  --with-default-content   # Load default content (force reset database if --skip-db-reset is not used)
  --with-dependencies      # Run composer and yarn install
  --group=<group>          # Only runs tests from the specified group(s)
  --exclude-group=<group>  # Exclude tests from the specified group(s)
  --tests-only             # Same as --skip-db-empty
  --help                   # Display phpunit help
  -- <...>                 # any phpunit valid args
```

*quality-check* run tools like _phpcs_, _phpmd_ and _phpcpd_ and print a report about code issues. This
action don't fail if any of theses commands reporting errors.

Available options are:

```bash
docker-compose exec test docker-as-drupal quality-check [options]

  --skip-phpcs             # Do not run phpcs
  --skip-phpmd             # Do not run phpmd
  --skip-phpcpd            # Do not run phpcpd
  --fail-on-phpcs          # Command fail if phpcs fail too
  --fail-on-phpmd          # Command fail if phpmd fail too
  --fail-on-phpcpd         # Command fail if phpcpd fail too
```

## Work on the docker image
A [Github Action Workflow](.github/workflows/ci.yml) is responsible to test, build and publish docker image.

You can also locally build all images or a specific one:

```bash
./tools.sh --build=<7.2-node9|all|latest>
```

Run tests (you will need first to install [container-structure-test](https://github.com/GoogleContainerTools/container-structure-test)):

```bash
./tools.sh --test=<7.2-node9|all|latest>
```

But all of this is automated with Github.