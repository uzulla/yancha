use strict;
use warnings;
use PocketIO::Test;
use t::Utils;
use AnyEvent;
use Yancha::Client;

BEGIN {
    use Test::More;
    plan skip_all => 'PocketIO::Client::IO are required to run this test'
      unless eval { require PocketIO::Client::IO; 1 };
}

my $testdb = t::Utils->setup_testdb( schema => './db/init.sql' );
my $config = { database => { connect_info => [ $testdb->dsn ] } };
my $server = t::Utils->server_with_dbi( config => $config );

my $client = sub {
    my ( $port ) = shift;
    my $client = Yancha::Client->new();

    my $cv = AnyEvent->condvar;
    my $w; $w = AnyEvent->timer( after => 30, cb => sub {
        fail("Time out.");
        $cv->send;
    } );

    ok( $client->login(
            "http://localhost:$port/", => 'login', { nick => 'test_client' }
      ), 'login' );
    ok( $client->connect, 'connect' );

    $client->run(sub {
        my ( $self, $socket ) = @_;

        $socket->on('nicknames', sub {
            is( $_[1]->{ test_client }, 'test_client', 'token login' );
            $cv->send;
        });

        $socket->emit('token login', $self->token);

    });

    $cv->wait;

};

test_pocketio $server, $client;


done_testing;


