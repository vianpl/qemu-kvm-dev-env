#!/bin/sh

# This script is called by udhcpc when it gets a lease

case "$1" in
    deconfig)
        ip addr flush dev $interface
        ;;

    renew|bound)
        ip addr add $ip/$mask dev $interface
        ip route add default via $router
        ;;
esac
