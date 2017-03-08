#!/bin/bash

DC2HOME=/usr/local/destcloud/core/

export RUBYLIB=$DC2HOME:$RUBYLIB

if [ -x /usr/bin/daemon ]; then
    /usr/bin/daemon -n destcloud2 -i -D / /usr/local/destcloud/core/destcloud2.rb
else
    /usr/local/destcloud/core/destcloud2.rb > /dev/null 2>&1 &
    sleep 1
    echo `ps -ax | grep destcloud2.rb | grep -v grep | awk '{print $1;}'` > /var/run/destcloud2.pid
fi

exit 0
