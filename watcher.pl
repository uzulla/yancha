#!/usr/bin/env perl
use strict;
use utf8;
use warnings;
use Time::Piece;
use LWP::UserAgent;

my $YANCHA_URL = 'http://localhost:3000/';

my $ua = LWP::UserAgent->new;
$ua->timeout(10);
print localtime->datetime;
print " watch start\n";

while(1){
    my $response =  eval {
    local $SIG{ALRM} = sub { die HTTP::Response->new(408, "got alarm, read timeout.") };
        alarm 10;
        my $res = $ua->get($YANCHA_URL);
        alarm 0;
        $res;
    };

    if ($response->is_success) {
        # print "OK\n";
    }else{
        print localtime->datetime;
        print " NG! \n";
        `kill \`cat yancha.pid\``;
        # must restart
        `nohup ./start.sh >> start.sh.log 2>&1 &`;
    }
    sleep 10;
}

=pod
Yancha Auto Rebooter
Author: uzulla

HOW TO START
0. edit watcher.pl ($YANCHA_URL)
1. run watcher.pl (You can use this an alternate for start.sh.)

HOW TO STOP
1, kill watchr.pl
2, stop.sh

=cut
