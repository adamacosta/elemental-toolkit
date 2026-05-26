#!/bin/sh

set -e

ROOT_DIR="$(dirname "$(dirname "$(realpath "$0")")")"

GIT_TAG=$(git describe --abbrev=0 --tags)

FLAVOR="${1:-minimal}"
VERSION="${2:-$GIT_TAG}"
REPO="local/elemental-${FLAVOR}:${VERSION}"

sed 's/^\(.*set kernelcmd=.*\)"/\1 rd\.break rd\.debug"/' \
  "$ROOT_DIR/pkg/features/embedded/grub-default-bootargs/etc/elemental/bootargs.cfg" \
  >"$ROOT_DIR/examples/$FLAVOR/bootargs.cfg"

[ -f "$ROOT_DIR/examples/$FLAVOR/SCCcredentials" ] || "$ROOT_DIR/scripts/scc-credentials.sh" "$FLAVOR"

cat <<EOF | docker build --tag "${REPO}-debug" -f- "$ROOT_DIR/examples/$FLAVOR"
FROM $REPO
COPY bootargs.cfg /etc/elemental/bootargs.cfg
COPY SCCcredentials /etc/zypp/credentials.d/SCCcredentials
RUN zypper install -y \
    bind-utils \
    efibootmgr \
    efivar \
    netcat-openbsd \
    net-snmp \
    nfs-client \
    strace \
    tcpdump && \
    zypper clean --all && \
    sed -i 's/^# \(add_dracutmodules.*$\)/\1/' /etc/dracut.conf.d/99-debug.conf && \
    rm -f /etc/zypp/credentials.d/SCCcredentials && \
    elemental init --force
EOF

rm -f "$ROOT_DIR/examples/$FLAVOR/bootargs.cfg"

sudo ./build/elemental --debug build-disk \
  --cloud-init "$ROOT_DIR/tests/assets/user_setup.yaml" \
  --expandable \
  --local \
  --name "elemental-${FLAVOR}-debug" \
  --output "$ROOT_DIR/build" \
  --platform linux/x86_64 \
  --snapshotter.type loopdevice \
  --system "${REPO}-debug"

qemu-img convert -O qcow2 \
  "$ROOT_DIR/build/elemental-${FLAVOR}-debug.raw" \
  "$ROOT_DIR/build/elemental-${FLAVOR}-debug.qcow2"

qemu-img resize "$ROOT_DIR/build/elemental-${FLAVOR}-debug.qcow2" 20G
