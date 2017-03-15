#!/usr/bin/env sh

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

set -e

error() {
    echo "$@"
    exit 1
}

[ -z "$1" ] && error "usage: $0 <install directory, e.g. /usr/local/bin>"
[ `id -u` = 0 ] && error "This should not be run as root!"

cd `dirname $0`
set -x
shards build --production
sudo install -m 755 bin/rcmake "$1/rcmake"
