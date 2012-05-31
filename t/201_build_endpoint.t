use strict;
use warnings;
use PocketIO::Test;
use Yancha;
use t::Utils;
use AnyEvent;
use Yancha::Client;
use Yancha::DataStorage::DBI;
use Plack::Builder;
use utf8;

BEGIN {
    use Test::More;
    plan skip_all => 'Test::mysqld and PocketIO::Client::IO are required to run this test'
      unless eval { require Test::mysqld; require PocketIO::Client::IO; 1 };
}

my $mysqld = t::Utils->setup_mysqld( schema => './db/init.sql' );
my $config = {
    database => { connect_info => [ $mysqld->dsn ] },
    'server_info' => {
        version       => '1.00',
        name          => 'Hachoji.pm',
        default_tag   => 'PUBLIC',
        introduction  => 'テストサーバ',
        auth_endpoint => {
            '/login' => [ 'Simple'  => { name_field => 'nick' } => {} ],
        }
    },
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

        $client->socket->on('server info' => sub {
            is_deeply( $_[1], $sys->_server_info( $config->{ server_info } ), 'server info' );
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

