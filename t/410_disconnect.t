use strict;
use warnings;
use PocketIO::Test;
use t::Utils;
use AnyEvent;
use Yancha::Client;

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

        $client->socket->on('nicknames' => sub {
            my @nicknames = sort keys %{ $_[1] };

            if ( @nicknames >= 2 ) {
                is_deeply( \@nicknames, [qw/client1 client2/], 'two uesrs' );
                $count++;
            }
            elsif ( $count ) {
                is_deeply( \@nicknames, [qw/client1/], 'disconnected' );
                $cv->send;
            }

        });

    };

    my ( $client1, $client2 ) = t::Utils->create_clients_and_set_tags(
        $port,
        { nickname => 'client1', on_connect => $on_connect }, 
        { nickname => 'client2' },
    );

    my $timer = AnyEvent->timer( after => 3, cb => sub {
        $client2->socket->close;
    } );

    $cv->wait;
};

test_pocketio $server, $client;

ok(1, 'test done');

done_testing;

