#!/bin/sh

twiggy_opt="-l :3000"
if [ "$YANCHA_DEBUG" != "" ] ; then
  if [ $YANCHA_DEBUG -gt 0 ] ; then
    twiggy_opt="$twiggy_opt -r"
  fi
fi
carton exec -- twiggy $twiggy_opt chat.psgi

#export YANCHA_DEBUG=1
#carton exec -- twiggy -l :3000 --access-log access_log chat.psgi &
#echo $! > yancha.pid
