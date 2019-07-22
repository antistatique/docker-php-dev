#!/usr/bin/env bash
set -e

VERSION_TO_UPDATE="all"
USE_CACHE=1
PHP_LAST_VERSION=$(find ./php/* -maxdepth 1 -prune -type d -exec basename {} \; | sort -n | tail -n 1)
NODE_LAST_VERSION=$(find ./php/$PHP_LAST_VERSION/node/* -maxdepth 1 -prune -type d -exec basename {} \; | sort -n | tail -n 1)

# Options
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
       echo "update.sh - update Dockerfile and scripts for all versions"
       echo " "
       echo "update.sh [options]"
       echo " "
       echo "options:"
       echo "-h, --help                show brief help"
       echo "-b, --build=VERSION       VERSION is optional, all images are build by default; set a VERSION like '7.2-node8'"
       echo "--publish=VERSION         set a VERSION like '7.2-node8' or 'all'; publish also build images"
       echo "--no-cache"               do not pull image from repository previously to build it
       echo "--clean"                  clean all local tags of the imahe
       exit 0
       ;;
    -b|--build*)
      VERSION_TO_BUILD="${1#*=}"
      if [ "$1" = "--build" ] || [ "$1" = "-b" ]; then
        VERSION_TO_BUILD="all"
      fi
      VERSION_TO_UPDATE=$VERSION_TO_BUILD
      ;;
    --publish=*)
      VERSION_TO_PUBLISH="${1#*=}"
      if [ -z "$VERSION_TO_PUBLISH" ]; then
        echo "VERSION to publish must be set"
        exit 1
      fi
      VERSION_TO_BUILD=$VERSION_TO_PUBLISH
      VERSION_TO_UPDATE=$VERSION_TO_PUBLISH
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

function publish {
  (
    set -e
    TAG=$(tag $1 $2)

    echo "** publish antistatique/php-dev:$TAG"
    docker push antistatique/php-dev:$TAG
  )
}

function process {
  phpVersion=$1
  nodeVersion=$2
  tag=$(tag $1 $2)

  if [ "$VERSION_TO_UPDATE" != "all" ] && [ "$VERSION_TO_UPDATE" != "$tag" ]; then
    echo "** skip php-dev:$tag"
    return
  fi

  echo "** update files for php-dev:$tag"

  if [ -z "$nodeVersion" ]; then
    DOCKERFILE_PATH=$(pwd)/php/$phpVersion/Dockerfile
  else
    DOCKERFILE_PATH=$(pwd)/php/$phpVersion/node/$nodeVersion/Dockerfile
  fi
  DOCKERFILE_DIR=$(dirname $DOCKERFILE_PATH)

  mkdir -p $DOCKERFILE_DIR/scripts

  # cleanup removed scripts
  for file in `diff <(cd $(pwd)/scripts; find . -type f | sort) <(cd $DOCKERFILE_DIR/scripts; find .  -type f | sort) | grep "^>" | awk -F/ '{print "'"$DOCKERFILE_DIR/scripts/"'" $2}'`; do
    (
      set -e

      git rm -f -q --ignore-unmatch $file
      rm -f $file
      echo "removed $file"
    )
  done

  # copy scripts
  cp ./scripts/* $DOCKERFILE_DIR/scripts/
  chmod 774 $DOCKERFILE_DIR/scripts/*

  # copy Dockerfile
  sed \
    -e "s!%%PHP_VERSION%%!${phpVersion}!g" \
    -e "s!%%NODE_VERSION%%!${nodeVersion:-"false"}!g" \
    ./Dockerfile > "$DOCKERFILE_PATH"

  # build docker imge if required
  if [ "$VERSION_TO_BUILD" = "all" ] || [ "$VERSION_TO_BUILD" = "$tag" ]; then
    if [ "$USE_CACHE" -gt 0 ]; then
      pull $phpVersion $nodeVersion
    fi
    build $phpVersion $nodeVersion
  fi

  # publish docker imge if required
  if [ "$VERSION_TO_PUBLISH" = "all" ] || [ "$VERSION_TO_PUBLISH" = "$tag" ]; then
    publish $phpVersion $nodeVersion
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
if [ "$VERSION_TO_BUILD" = "all" ] || [ "$VERSION_TO_BUILD" = "$PHP_LAST_VERSION-node$NODE_LAST_VERSION" ]; then
  docker tag antistatique/php-dev:$PHP_LAST_VERSION-node$NODE_LAST_VERSION antistatique/php-dev:latest
fi

if [ "$VERSION_TO_PUBLISH" = "all" ] || [ "$VERSION_TO_PUBLISH" = "$PHP_LAST_VERSION-node$NODE_LAST_VERSION" ]; then
  publish "latest"
fi
