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
my $config = {
    'database' => { connect_info => [ $testdb->dsn ] },
    'plugins' => [
        [
            'Yancha::Plugin::WelcomeMessage' => [
                message => 'Welcome %s! This is test.',
            ]
        ],
    ],
};
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

        $client->socket->on('announcement' => sub {
            is( $_[1], 'Welcome user! This is test.' );
            $cv->send;
        });

    };

    my ( $client ) = t::Utils->create_clients_and_set_tags(
        $port,
        { nickname => 'user', tags => ['hoge'] ,on_connect => $on_connect },
    );

    $cv->wait;
};

test_pocketio $server, $client;

ok(1, 'test done');

done_testing;

