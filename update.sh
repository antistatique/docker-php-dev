#!/usr/bin/env bash
set -e

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
       echo "-b, --build=VERSION       VERSION is optional, all images are build by default; or set a VERSION like '7.2-node8'"
       echo "--publish=VERSION         set a VERSION like '7.2-node8' or 'all'; publish also build image"
       exit 0
       ;;
    -b|--build*)
      VERSION_TO_BUILD=`echo $1 | sed -e 's/^[^=]*=//g'`
      if [[ "$VERSION_TO_BUILD" == "--build" || "$VERSION_TO_BUILD" == "-b" ]]; then
        VERSION_TO_BUILD="all"
      fi
      shift
      ;;
    --publish*)
      VERSION_TO_PUBLISH=`echo $1 | sed -e 's/^[^=]*=//g'`
      if [[ "$VERSION_TO_PUBLISH" == "--publish" ]]; then
        echo "VERSION to publish must set"
        exit 1
      fi
      VERSION_TO_BUILD=$VERSION_TO_PUBLISH
      shift
      ;;
     *)
       break
       ;;
  esac
done

# functions

function build() {
  (
    set -e

    echo "** build php-dev:$1-node$2"
    cd ./php/$1/node/$2/

    docker build -t antistatique/php-dev:$1-node$2 .
  )
}

function publish() {
  (
    set -e

    echo "** publish php-dev:$1-node$2"
    cd ./php/$1/node/$2/

    docker push antistatique/php-dev:$1-node$2
  )
}


# Go through versions
for phpVersion in `find ./php/* -maxdepth 1 -prune -type d -exec basename {} \;`; do
  for nodeVersion in `find ./php/$phpVersion/node/* -maxdepth 1 -prune -type d -exec basename {} \;`; do
    echo "** update files for php-dev:$phpVersion-node$nodeVersion"

    # cleanup removed scripts
    for file in `diff <(cd ./scripts; find -s . -type f) <(cd ./php/$phpVersion/node/$nodeVersion/scripts; find -s .  -type f) | grep "^>" | awk '{print $2}'`; do
      (
        set -e

        path="./php/$phpVersion/node/$nodeVersion/scripts/$(basename $file)"

        git rm -f -q --ignore-unmatch $path
        rm -f $path
        echo "removed $path"
      )
    done

    # copy Dockerfile template and scripts
    dockerfilePath=./php/$phpVersion/node/$nodeVersion/Dockerfile
    cp ./Dockerfile.template $dockerfilePath
    mkdir -p ./php/$phpVersion/node/$nodeVersion/scripts
    cp ./scripts/* ./php/$phpVersion/node/$nodeVersion/scripts/

    # update Dockerfile
    sed -i '' \
      -e "s!%%PHP_VERSION%%!${phpVersion}!g" \
      -e "s!%%NODE_VERSION%%!${nodeVersion}!g" \
      "$dockerfilePath"

    # build docker imge if required
    if [[ "$VERSION_TO_BUILD" == "all" || "$VERSION_TO_BUILD" == "$phpVersion-node$nodeVersion" ]]; then
      build $phpVersion $nodeVersion
    fi

    # publish docker imge if required
    if [[ "$VERSION_TO_PUBLISH" == "all" || "$VERSION_TO_PUBLISH" == "$phpVersion-node$nodeVersion" ]]; then
      publish $phpVersion $nodeVersion
    fi
  done
done
