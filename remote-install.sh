#!/usr/bin/env sh

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

set -e

URL="https://github.com/kirbyfan64/rcmake/archive/master.tar.gz"
INSTALL_TARGET="${1:-/usr/local/bin}"

error() {
    echo "$@" >&2
    exit 1
}

ensure_present() {
    which "$1" >/dev/null 2>&1 || error "$2"
}

echo "Running system checks..."

[ `id -u` = 0 ] && error "This should not be run as root!"
ensure_present curl "curl is required to download rcmake's source code."
ensure_present crystal "Crystal is required to build rcmake."
ensure_present shards "Shards (which usually comes with Crystal) is required to build rcmake."

set -x

cd ${TMP:-/tmp}
curl -fL "$URL" -o rcmake.tar.gz
tar xvf rcmake.tar.gz

cd rcmake-master
sh install.sh "$INSTALL_TARGET"
