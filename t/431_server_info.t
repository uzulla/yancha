use strict;
use warnings;
use PocketIO::Test;
use Yancha;
use t::Utils;
use AnyEvent;
use Yancha::Client;

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
            '/login' => [ 'Yancha::Auth::Simple'  => { name_field => 'nick' } => { description => "simpleなログインです" } ],
        }
    },
};
my $server = t::Utils->server_with_dbi( config => $config );

my $client = sub {
    my ( $port ) = shift;

    my $cv = AnyEvent->condvar;
    my $w  = AnyEvent->timer( after => 10, cb => sub {
        fail("Time out.");
        $cv->send;
    } );

    my $client = Yancha::Client->new();

    $client->connect("http://localhost:$port/");

    $client->run( sub {
        $client->socket->on('server info' => sub {
            is_deeply( $_[1],  {
                version       => '1.00',
                name          => 'Hachoji.pm',
                default_tag   => 'PUBLIC',
                introduction  => 'テストサーバ',
                auth_endpoint => {
                    '/login' => { name_field => 'nick', description => 'simpleなログインです' },
                }
            }, 'server info' );
            $cv->send;
        });
        $client->socket->emit('server info');
    } );

    $cv->wait;
};

test_pocketio $server, $client;

ok(1, 'test done');

done_testing;

