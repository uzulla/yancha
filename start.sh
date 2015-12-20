#!/bin/sh
#carton exec -- twiggy -l :3000 chat.psgi
#export PERL_ANYEVENT_LOG="filter=trace:log=+%file:%file=file=/tmp/mylog"
export YANCHA_DEBUG=1
#export POCKETIO_HANDLE_DEBUG=1
#export POCKETIO_CONNECTION_DEBUG=1
#export POCKETIO_POOL_DEBUG=1
#export POCKETIO_RESOURCE_DEBUG=1
#export POCKETIO_DEBUG=1
carton exec -- twiggy -l :3000 --access-log access_log chat.psgi &
echo $! > yancha.pid
