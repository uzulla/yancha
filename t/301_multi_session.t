use strict;
use warnings;
use PocketIO::Test;
use t::Utils;
use AnyEvent;
use Yairc::Client;
use Data::Dumper;

BEGIN {
    use Test::More;
    plan skip_all => 'Test::mysqld and PocketIO::Client::IO are required to run this test'
      unless eval { require Test::mysqld; require PocketIO::Client::IO; 1 };
}

my $mysqld = t::Utils->setup_mysqld( schema => './db/init.sql' );
my $config = {
    database => { connect_info => [ $mysqld->dsn ] },
    token_expiration_sec => 10,
};
my $server = t::Utils->server_with_dbi( config => $config );

my $storage = Yairc::DataStorage::DBI->connect( connect_info => [ $mysqld->dsn ] );

my $client = sub {
    my ( $port ) = shift;
    my $client = Yairc::Client->new();

    my $client_test = sub {
        my ( $nickname ) = @_;

        my $cv = AnyEvent->condvar;
        my $w; $w = AnyEvent->timer( after => 10, cb => sub {
            fail("Time out.");
            $cv->send;
        } );

        ok( $client->login(
                "http://localhost:$port/", => 'login', { nick => $nickname }
          ), 'login' );
        ok( $client->connect, 'connect' );

        $client->run(sub {
            my ( $self, $socket ) = @_;

            $socket->on('token login', sub {
                is( $_[1]->{ status }, 'ok', 'token login' );
                my $user = $storage->get_user_by_token( $client->token );
                is( $user->{ nickname }, $nickname, 'user nickname ' . $nickname );
                is( $user->{ token }, $client->token, 'user has token' );
                my $session = $storage->get_session_by_token( $client->token );
                is( $session->{ token }, $client->token, $client->token );
                $cv->send( $user );
            });

            $socket->emit('token login', $self->token);

        });

        return $cv->wait;
    };

    my $user1 = $client_test->( "user" );
    my $user2 = $client_test->( "user" );

    ok( $user1->{ token } ne $user2->{ token } );

    my $sessions = $storage->dbh->selectall_arrayref('SELECT * FROM session');
    is( scalar(@$sessions), 2 );

    my $cv = AnyEvent->condvar;
    my $timer = AnyEvent->timer( after => 10, cb => sub {
        $storage->clear_expire_token();
        $cv->send;
    } );
    $cv->wait;

    $sessions = $storage->dbh->selectall_arrayref('SELECT * FROM session');
    is( scalar(@$sessions), 0 );

};

test_pocketio $server, $client;


done_testing;


