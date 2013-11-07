use strict;
use warnings;
use PocketIO::Test;
use t::Utils;
use AnyEvent;
use Yancha::Client;

use Test::More;

my $testdb = t::Utils->setup_testdb( schema => './db/init.sql' );
my $config = {
    database => { connect_info => [ $testdb->dsn ] },
};
my $server = t::Utils->server_with_dbi( config => $config );

my $client = sub {
    my $port = shift;
    my ($client1) = t::Utils->create_clients_and_set_tags(
        $port,
        { nickname => 'client1' },
    );

    my $cv = AnyEvent->condvar;
    my $w  = AnyEvent->timer( after => 15, cb => sub {
        fail("Time out.");
        $cv->end;
    } );

    $cv->begin;

    $client1->socket->on('user message', sub {
        my $post = $_[1];
        my $expected_regex = qr/User-Agent: UNKNOWN\nRemote-Address: 127\.0\.0\.1\nServer: localhost:\d+\n \#PUBLIC/;
        like $post->{ text }, $expected_regex, 'Get client information rightly by `fukumotosan`';
        $cv->end;
    });

    $client1->socket->emit('fukumotosan');

    $cv->wait;
};

test_pocketio $server, $client;

done_testing;
