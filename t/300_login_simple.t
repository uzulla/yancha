use strict;
use warnings;
use PocketIO::Test;
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
    my $client = Yairc::Client->new();

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

        $socket->emit('token_login', $self->token);
        $socket->on('nicknames', sub {
            is( $_[1]->{ test_client }, 'test_client', 'token_login' );
            $cv->send;
        });

    });

    $cv->wait;

};

test_pocketio $server, $client;


done_testing;


