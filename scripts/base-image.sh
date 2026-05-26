#!/bin/sh

set -e

ROOT_DIR="$(dirname "$(dirname "$(realpath "$0")")")"

GIT_TAG=$(git describe --abbrev=0 --tags)

FLAVOR="${1:-minimal}"
VERSION="${2:-$GIT_TAG}"
REPO="local/elemental-${FLAVOR}"

[ -f "$ROOT_DIR/tests/assets/user_setup.yaml" ] || "$ROOT_DIR/scripts/cloudinit-user.sh"

[ -f "$ROOT_DIR/examples/$FLAVOR/SCCcredentials" ] || "$ROOT_DIR/scripts/scc-credentials.sh" "$FLAVOR"

docker build \
  --build-arg IMAGE_REPO="$REPO" \
  --build-arg IMAGE_TAG="$VERSION" \
  --tag "$REPO:$VERSION" \
  "$ROOT_DIR/examples/$FLAVOR"

sudo ./build/elemental --debug build-disk \
  --cloud-init "$ROOT_DIR/tests/assets/user_setup.yaml" \
  --expandable \
  --local \
  --name "elemental-${FLAVOR}" \
  --output "$ROOT_DIR/build" \
  --platform linux/x86_64 \
  --snapshotter.type loopdevice \
  --system "$REPO:$VERSION"

qemu-img convert -O qcow2 \
  "$ROOT_DIR/build/elemental-${FLAVOR}.raw" \
  "$ROOT_DIR/build/elemental-${FLAVOR}.qcow2"

qemu-img resize "$ROOT_DIR/build/elemental-${FLAVOR}.qcow2" 20G
