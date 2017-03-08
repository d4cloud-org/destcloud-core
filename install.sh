#!/bin/bash

DESTDIR=/usr/local/destcloud/core

if [ x"${EUID:-${UID}}" = "x0" ]; then
    mkdir -p $DESTDIR

    cp *.rb $DESTDIR
    cp *.sh $DESTDIR
    chmod +x $DESTDIR/destcloud2.rb
    chmod +x $DESTDIR/destcloud2.sh

    cp destcloud2.service /etc/systemd/system/
    systemctl daemon-reload
    echo 'Installation done.'
else
    echo 'please execute this script as root.'
    exit 1
fi



