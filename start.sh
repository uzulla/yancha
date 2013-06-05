#!/bin/sh
twiggy -l :3000  chat.psgi 
#export YANCHA_DEBUG=1
#twiggy -l :3000 --access-log access_log chat.psgi &
echo $! > yancha.pid
