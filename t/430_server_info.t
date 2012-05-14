use strict;
use warnings;
use PocketIO::Test;
use Yairc;
use t::Utils;
use AnyEvent;
use Yairc::Client;

BEGIN {
    use Test::More;
    plan skip_all => 'Test::mysqld and PocketIO::Client::IO are required to run this test'
      unless eval { require Test::mysqld; require PocketIO::Client::IO; 1 };
}

my $mysqld = t::Utils->setup_mysqld( schema => './db/init.sql' );
my $config = { database => { connect_info => [ $mysqld->dsn ] } };
my $server = t::Utils->server_with_dbi( config => $config );

my $client = sub {
    my ( $port ) = shift;

    my $cv = AnyEvent->condvar;
    my $w  = AnyEvent->timer( after => 10, cb => sub {
        fail("Time out.");
        $cv->send;
    } );

    my $on_connect = sub {
        my ( $client ) = @_;
        my $count = 0;

        $client->socket->on('server info' => sub {
            is_deeply( $_[1], $Yairc::SERVER_INFO, 'server info' );
            $cv->send;
        });

    };

    my ( $client ) = t::Utils->create_clients_and_set_tags(
        $port,
        { nickname => 'client', on_connect => $on_connect }, 
    );

    $client->socket->emit('server info');

    $cv->wait;
};

test_pocketio $server, $client;

ok(1, 'test done');

done_testing;

