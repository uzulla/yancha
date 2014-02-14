use strict;
use warnings;
use PocketIO::Test;
use t::Utils;
use AnyEvent;
use Yancha;
use Yancha::Client;
use Yancha::DataStorage::DBI;
use Plack::Builder;

BEGIN {
    use Test::More;
    plan skip_all => 'PocketIO::Client::IO are required to run this test'
      unless eval { require PocketIO::Client::IO; 1 };
}

my $testdb = t::Utils->setup_testdb( schema => './db/init.sql' );
my $config = {
    'database' => { connect_info => [ $testdb->dsn ] },
    'server_info' => {
        default_tag   => 'PUBLIC',
        auth_endpoint => {
            '/login' => [ 'Yancha::Auth::Simple'  => { name_field => 'nick' } => {} ],
        }
    },

    'plugins' => [
        [ 'Yancha::Plugin::NoRec' ],
    ],
};
my $data_storage = Yancha::DataStorage::DBI->connect(
                            connect_info => $config->{ database }->{ connect_info } );

my $sys = Yancha->new( config => $config, data_storage => $data_storage );
my $server = builder {
    enable 'Session';
    $sys->build_psgi_endpoint_from_server_info('auth');
    mount '/socket.io' => PocketIO->new(
            socketio => $config->{ socketio },
            instance => $sys,
    );
};

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

        $client->socket->on('pong' => sub {
            my $post = $_[1];

            is( $post, 'my_uuid' );

            $cv->send;
        });

    };

    my ( $client ) = t::Utils->create_clients_and_set_tags(
        $port,
        { nickname => 'user', on_connect => $on_connect },
    );

    $client->socket->emit('ping', "my_uuid");


    $cv->wait;
};

test_pocketio $server, $client;

ok(1, 'test done');

done_testing;

