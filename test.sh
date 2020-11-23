#!/usr/bin/env bash
set -e

scriptDir=$( cd "$(dirname "${BASH_SOURCE}")" ; pwd -P )

VERSION_TO_TEST="all"
USE_CACHE=1
PHP_LAST_VERSION=$(find ./php/* -maxdepth 1 -prune -type d -exec basename {} \; | sort -n | tail -n 1)
NODE_LAST_VERSION=$(find ./php/$PHP_LAST_VERSION/node/* -maxdepth 1 -prune -type d -exec basename {} \; | sort -n | tail -n 1)

# Options
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
       echo "test.sh - test Dockerfile and scripts for all versions"
       echo " "
       echo "test.sh [options]"
       echo " "
       echo "options:"
       echo "-h, --help                show brief help"
       echo "-t, --test=VERSION        VERSION is optional, all images are tested by default; set a VERSION like '7.2-node8'"
       echo "--no-cache"               do not pull image from repository previously to build it
       echo "--clean"                  clean all local tags of the imahe
       exit 0
       ;;
    -t|--test*)
      VERSION_TO_TEST="${1#*=}"
      if [ "$1" = "--test" ] || [ "$1" = "-t" ]; then
        VERSION_TO_TEST="all"
      fi
      VERSION_TO_TEST=$VERSION_TO_TEST
      ;;
    --no-cache)
      USE_CACHE=0
      ;;
    --clean)
      if [ ! -z "$(docker images | grep antistatique/php-dev | tr -s ' ' | cut -d ' ' -f 2 | grep -v '<none>')" ]; then
        docker images | grep antistatique/php-dev | tr -s ' ' | cut -d ' ' -f 2 | grep -v '<none>' | xargs -I {} docker rmi antistatique/php-dev:{}
      fi
      echo "** images cleanded"
      exit 0
      ;;
  esac
  shift
done

# functions

function tag {
  if [ "$1" = "latest" ]; then
    echo "latest"
  elif [ ! -z "$2" ]; then
    echo "$1-node$2"
  else
    echo "$1"
  fi
}

function pull {
  (
    set +e
    TAG=$(tag $1 $2)

    docker pull antistatique/php-dev:$TAG || true
  )
}

function build {
  (
    set -e
    TAG=$(tag $1 $2)

    echo "** build antistatique/php-dev:$TAG"
    if [ -z "$2" ]; then
      cd ./php/$1/
    else
      cd ./php/$1/node/$2/
    fi
    docker build -t antistatique/php-dev:$TAG .
  )
}

function test {
  (
    set -e
    TAG=$(tag $1 $2)

    echo "** test antistatique/php-dev:$TAG"
    if [ -z "$2" ]; then
      cd ./php/$1/
    else
      cd ./php/$1/node/$2/
    fi

    # Ensure base metadata.
    container-structure-test test --image antistatique/php-dev:${TAG} --config ${scriptDir}/php/tests/baseMetadataTests.yaml

    # Ensure base file existences.
    container-structure-test test --image antistatique/php-dev:${TAG} --config ${scriptDir}/php/tests/baseFileExistenceTests.yaml

    # Image specific structure testing.
    container-structure-test test --image antistatique/php-dev:${TAG} --config ${scriptDir}/php/$1/tests/config--${TAG}.yaml
  )
}

function process {
  phpVersion=$1
  nodeVersion=$2
  tag=$(tag $1 $2)

  if [ "$VERSION_TO_TEST" != "all" ] && [ "$VERSION_TO_TEST" != "$tag" ]; then
    echo "** skip php-dev:$tag"
    return
  fi

  echo "** test files for php-dev:$tag"

  # build docker imge if required
  if [ "$VERSION_TO_TEST" = "all" ] || [ "$VERSION_TO_TEST" = "$tag" ]; then
    if [ "$USE_CACHE" -gt 0 ]; then
      pull $phpVersion $nodeVersion
    fi
    build $phpVersion $nodeVersion
    test $phpVersion $nodeVersion
  fi
}

# Go through versions
for phpVersion in `find ./php/* -maxdepth 1 -prune -type d -exec basename {} \; | sort -n`; do
  process $phpVersion
  for nodeVersion in `find ./php/$phpVersion/node/* -maxdepth 1 -prune -type d -exec basename {} \; | sort -n`; do
    process $phpVersion $nodeVersion
  done
done

# tag latest version
if [ "$VERSION_TO_TEST" = "all" ] || [ "$VERSION_TO_TEST" = "$PHP_LAST_VERSION-node$NODE_LAST_VERSION" ]; then
  docker tag antistatique/php-dev:$PHP_LAST_VERSION-node$NODE_LAST_VERSION antistatique/php-dev:latest
fi
