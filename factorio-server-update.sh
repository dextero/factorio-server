#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
FACTORIO_DOCKER_REPO="$SCRIPT_DIR/factorio-docker"
BUILDINFO_JSON_FILE="$FACTORIO_DOCKER_REPO/buildinfo.json"
DOCKER_COMPOSE_FILE="$FACTORIO_DOCKER_REPO/docker/docker-compose.yml"

cp "$DOCKER_COMPOSE_FILE" "${DOCKER_COMPOSE_FILE}.bak"
CURRENT_VERSION="$(grep 'VERSION=' "$DOCKER_COMPOSE_FILE" | sed -e 's/^.*VERSION=//')"
CURRENT_SHA256="$(grep 'SHA256=' "$DOCKER_COMPOSE_FILE" | sed -e 's/^.*SHA256=//')"

cd "$FACTORIO_DOCKER_REPO"
git stash || true
git checkout master
git pull

STABLE_VERSION_AND_SHA256=($(jq -r 'to_entries | map(select(.value.tags[] | contains("stable"))) | map("\(.key) \(.value.sha256)") | .[0]' "$BUILDINFO_JSON_FILE"))
STABLE_VERSION="${STABLE_VERSION_AND_SHA256[0]}"
STABLE_SHA256="${STABLE_VERSION_AND_SHA256[1]}"

echo " Stable version (sha256): $STABLE_VERSION ($STABLE_SHA256)"
echo "Current version (sha256): $CURRENT_VERSION ($CURRENT_SHA256)"

if [[ "$STABLE_VERSION" != "$CURRENT_VERSION" || "$STABLE_SHA256" != "$CURRENT_SHA256" ]]; then
    echo "Update required"

    echo "* Updating configured version to $STABLE_VERSION..."
    sed -e "s/VERSION=.*\$/VERSION=$STABLE_VERSION/" \
        -e "s/SHA256=.*\$/SHA256=$STABLE_SHA256/" \
	-e "s|/opt/factorio:|/home/dex/factorio:|" \
        -i "$DOCKER_COMPOSE_FILE"
    echo "* Updating docker image..."
    echo "** Stopping factorio-server.service..."
    sudo systemctl stop factorio-server.service
    echo "** Deleting docker image..."
    docker rmi docker_factorio || true
    echo "** Starting factorio-server.service..."
    sudo systemctl start factorio-server.service
    echo "* All done!"
else
    echo "Update not needed"
    git stash pop || true
fi
