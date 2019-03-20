#!/usr/bin/env bash
set -e

USE_CACHE=1
PHP_LAST_VERSION=$(find ./php/* -maxdepth 1 -prune -type d -exec basename {} \; | sort -n | tail -n 1)
NODE_LAST_VERSION=$(find ./php/$PHP_LAST_VERSION/node/* -maxdepth 1 -prune -type d -exec basename {} \; | sort -n | tail -n 1)

# Options
while test $# -gt 0; do
  case "$1" in
    -h|--help)
       echo "update.sh - update Dockerfile and scripts for all versions"
       echo " "
       echo "update.sh [options]"
       echo " "
       echo "options:"
       echo "-h, --help                show brief help"
       echo "-b, --build=VERSION       VERSION is optional, all images are build by default; set a VERSION like '7.2-node8', or 'latest'"
       echo "--no-cache"               do not pull image from repository previously to build it
       echo "--latest                  shortcut to build latest version (--build=latest)"
       echo "--publish=VERSION         set a VERSION like '7.2-node8', 'all', or 'latest'; publish also build images"
       exit 0
       ;;
    -b|--latest|--build*)
      VERSION_TO_BUILD=`echo $1 | sed -e 's/^[^=]*=//g'`
      if [[ "$VERSION_TO_BUILD" == "--build" || "$VERSION_TO_BUILD" == "-b" ]]; then
        VERSION_TO_BUILD="all"
      elif [[ "$VERSION_TO_BUILD" == "latest" || "$VERSION_TO_BUILD" == "--latest" ]]; then
        VERSION_TO_BUILD="$PHP_LAST_VERSION-node$NODE_LAST_VERSION"
      fi
      shift
      ;;
    --publish*)
      VERSION_TO_PUBLISH=`echo $1 | sed -e 's/^[^=]*=//g'`
      if [[ "$VERSION_TO_PUBLISH" == "--publish" ]]; then
        echo "VERSION to publish must set"
        exit 1
      elif [[ "$VERSION_TO_PUBLISH" == "latest" ]]; then
        VERSION_TO_PUBLISH="$PHP_LAST_VERSION-node$NODE_LAST_VERSION"
      fi
      VERSION_TO_BUILD=$VERSION_TO_PUBLISH
      shift
      ;;
    --no-cache)
      USE_CACHE=0
      ;;
     *)
       break
       ;;
  esac
done

# functions

function tag {
  if [[ "$1" == "latest" ]]; then
    echo "latest"
  else
    echo "$1-node$2"
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
    cd ./php/$1/node/$2/
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


# Go through versions
for phpVersion in `find ./php/* -maxdepth 1 -prune -type d -exec basename {} \; | sort -n`; do
  for nodeVersion in `find ./php/$phpVersion/node/* -maxdepth 1 -prune -type d -exec basename {} \; | sort -n`; do
    echo "** update files for php-dev:$phpVersion-node$nodeVersion"

    DOCKERFILE_PATH=$(pwd)/php/$phpVersion/node/$nodeVersion/Dockerfile
    DOCKERFILE_DIR=$(dirname $DOCKERFILE_PATH)

    mkdir -p $DOCKERFILE_DIR/scripts

    # cleanup removed scripts
    for file in `diff <(cd $(pwd)/scripts; find -s . -type f) <(cd $DOCKERFILE_DIR/scripts; find -s .  -type f) | grep "^>" | awk -F/ '{print "'"$DOCKERFILE_DIR/scripts/"'" $2}'`; do
      (
        set -e

        git rm -f -q --ignore-unmatch $file
        rm -f $file
        echo "removed $file"
      )
    done

    # copy Dockerfile template and scripts
    cp ./Dockerfile.template $DOCKERFILE_PATH
    cp ./scripts/* $DOCKERFILE_DIR/scripts/
    chmod 774 $DOCKERFILE_DIR/scripts/*

    # update Dockerfile
    sed -i '' \
      -e "s!%%PHP_VERSION%%!${phpVersion}!g" \
      -e "s!%%NODE_VERSION%%!${nodeVersion}!g" \
      "$DOCKERFILE_PATH"

    # Add to git
    git add $DOCKERFILE_PATH

    # build docker imge if required
    if [[ "$VERSION_TO_BUILD" == "all" || "$VERSION_TO_BUILD" == "$phpVersion-node$nodeVersion" ]]; then
      if [ "$USE_CACHE" -gt 0 ]; then
        pull $phpVersion $nodeVersion
      fi
      build $phpVersion $nodeVersion
    fi

    # publish docker imge if required
    if [[ "$VERSION_TO_PUBLISH" == "all" || "$VERSION_TO_PUBLISH" == "$phpVersion-node$nodeVersion" ]]; then
      publish $phpVersion $nodeVersion
    fi
  done
done

# tag latest version
if [[ "$VERSION_TO_BUILD" == "all" || "$VERSION_TO_BUILD" == "$PHP_LAST_VERSION-node$NODE_LAST_VERSION" ]]; then
  docker tag antistatique/php-dev:$PHP_LAST_VERSION-node$NODE_LAST_VERSION antistatique/php-dev:latest
fi

if [[ "$VERSION_TO_PUBLISH" == "all" || "$VERSION_TO_PUBLISH" == "$PHP_LAST_VERSION-node$NODE_LAST_VERSION" ]]; then
  publish "latest"
fi
