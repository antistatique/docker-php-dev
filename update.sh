#!/usr/bin/env bash
set -e

for phpVersion in `find ./php/* -maxdepth 1 -prune -type d -exec basename {} \;`; do
  for nodeVersion in `find ./php/$phpVersion/node/* -maxdepth 1 -prune -type d -exec basename {} \;`; do
    dockerfilePath=./php/$phpVersion/node/$nodeVersion/Dockerfile
    cp ./Dockerfile.template $dockerfilePath
    cp ./scripts/* ./php/$phpVersion/node/$nodeVersion/

    echo "update files for drupal-dev:php$phpVersion-node$nodeVersion"
    (
      sed -i '' \
        -e "s!%%PHP_VERSION%%!${phpVersion}!g" \
        -e "s!%%NODE_VERSION%%!${nodeVersion}!g" \
        "$dockerfilePath"

      if [[ "$@" == "--build" ]]; then
        cd ./php/$phpVersion/node/$nodeVersion/
        docker build -t drupal-dev:php$phpVersion-node$nodeVersion .
      fi
    )
  done
done
