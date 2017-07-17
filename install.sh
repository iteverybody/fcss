#!/bin/bash

set -o nounset
set -o errexit

if [[ $(whoami) != "root" ]]; then
    echo "You must be root!"
    exit 3
fi

rpm -ivh --force strongswan-5.4.0-2spi.el7.x86_64.rpm

sed -i "s/\([[:space:]]*load = \).*/\1no/" /etc/strongswan/strongswan.d/charon/farp.conf
sed -i "s/\([[:space:]]*load = \).*/\1no/" /etc/strongswan/strongswan.d/charon/dhcp.conf

touch /var/log/charon.log
\cp charon-logging.conf /etc/strongswan/strongswan.d/

echo -e '\nInstall Fake Fext successfully!\n'

