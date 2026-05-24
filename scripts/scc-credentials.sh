#!/bin/sh

ROOT_DIR="$(dirname $(dirname $(realpath $0)))"

[ -f "$ROOT_DIR/.env" ] && source "$ROOT_DIR/.env"

FLAVOR="${1:-minimal}"
SLES_REG_CODE="${2:-$SLES_REG_CODE}"

[ -z "$SLES_REG_CODE" ] && echo "Supply reg code" && exit 1

docker run --rm -it registry.suse.com/bci/bci-base:16.0 sh -c \
  "zypper --quiet install -y suseconnect 2>&1 >/dev/null && \
  suseconnect --regcode $SLES_REG_CODE 2>&1 >/dev/null && \
  cat /etc/zypp/credentials.d/SCCcredentials" \
  > "$ROOT_DIR/examples/$FLAVOR/SCCcredentials"