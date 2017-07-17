#!/bin/bash

set -o nounset
#set -o errexit

if [[ $(whoami) != "root" ]]; then
    echo "You must be root!"
    exit 3
fi

if [[ $# -ne 1 ]]; then
    echo "$0 start|stop"
    exit 4
else
    DO=$1   
fi

case "$DO" in
    "start")
        systemctl stop firewalld
        FEXT_NIC=$(grep FEXT_NIC fext.conf | awk -F '=' '{print $2}' | tr -d '[:space:]')
        FEXT_IP=$(grep FEXT_IP fext.conf | awk -F '=' '{print $2}' | tr -d '[:space:]')
        FEXT_SUBNET=$(grep FEXT_SUBNET fext.conf | awk -F '=' '{print $2}' | tr -d '[:space:]')
        FEXT_ID=$(grep FEXT_ID fext.conf | awk -F '=' '{print $2}' | tr -d '[:space:]')
        FEXT_PSK=$(grep FEXT_PSK fext.conf | awk -F '=' '{print $2}' | tr -d '[:space:]')
        DEMUX_IP=$(grep DEMUX_IP fext.conf | awk -F '=' '{print $2}' | tr -d '[:space:]')

        sysctl -wq net.ipv4.conf.default.send_redirects=0
        sysctl -wq net.ipv4.conf.${FEXT_NIC}.send_redirects=0
        sysctl -wq net.ipv4.conf.all.send_redirects=0
        sysctl -wq net.ipv4.conf.${FEXT_NIC}.accept_redirects=0
        sysctl -wq net.ipv4.conf.default.accept_redirects=0
        sysctl -wq net.ipv4.conf.all.accept_redirects=0
        sysctl -wq net.ipv4.ip_forward=1

        cp swanctl.tmpl swanctl.conf
        sed -i "s/\(.*local_addrs =\)\(.*\)/\1 ${FEXT_IP}/" swanctl.conf
        sed -i "s/\(.*remote_addrs =\)\(.*\)/\1 ${DEMUX_IP}/" swanctl.conf
        sed -i "s/\(.*id =\)\(.*FEXT_ID\)/\1 ${FEXT_ID}/" swanctl.conf
        sed -i "s@\(.*local_ts =\)\(.*\)@\1 ${FEXT_SUBNET}@" swanctl.conf
        sed -i "s/\(.*ike-\)\(DEMUX_IP\)\(.*\)/\1${DEMUX_IP}\3/" swanctl.conf
        sed -i "s/\(.*id =\)\(.*DEMUX_IP\)/\1 ${DEMUX_IP}/" swanctl.conf
        sed -i "s/\(.*secret =\)\(.*FEXT_PSK\)/\1 ${FEXT_PSK=}/" swanctl.conf
        \mv swanctl.conf /etc/strongswan/swanctl/swanctl.conf

        strongswan start
        sleep 1
        swanctl --load-all
        sleep 1
        swanctl --initiate --child net-net
        sleep 1
        ip rule add to ${FEXT_SUBNET} table 1
        ip route add default dev ${FEXT_NIC} table 1
        echo -e '\nHave a good trip!\n'
        ;;
    "stop")
        swanctl --terminate --child net-net
        sleep 1
        strongswan stop
        ip route flush table 1
        ip rule del table 1
        echo -e '\nGood Bye!\n'
        ;;
    *)
        echo "$0 start|stop"
        ;;
esac

