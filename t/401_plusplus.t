use strict;
use warnings;
use PocketIO::Test;
use t::Utils;
use AnyEvent;
use Yancha::Client;
use Yancha::DataStorage::DBI;

use Test::More;

my $testdb = t::Utils->setup_testdb( schema => './db/init.sql' );
my $config = {
    database => { connect_info => [ $testdb->dsn ] },
};

my $data_storage = Yancha::DataStorage::DBI->connect( %{$config->{database}} );
$data_storage->add_post( { text => "makamaka #PUBLIC", tags => [ 'PUBLIC' ] }, {
    nickname => 'user', user_key => '-:0001', profile_image_url => '',  profile_url => '',
} );

my $server = t::Utils->server_with_dbi( config => $config );

my $client = sub {
    my ( $port ) = shift;
    my ( $client1, $client2 ) = t::Utils->create_clients_and_set_tags(
        $port,
        { nickname => 'client1', tags => ['PUBLIC'] },
        { nickname => 'client2', tags => ['PUBLIC'] },
    );

    my $cv = AnyEvent->condvar;
    my $w  = AnyEvent->timer( after => 15, cb => sub {
        fail("Time out.");
        $cv->end;
    } );

    subtest 'does plusplus updated ?' => sub {
        $client2->socket->emit('plusplus', "1");

        $cv->begin;

        $client1->socket->on( 'user message', sub {
            my $post = $_[1];

            if($post->{id} == 1) {
                is $post->{plusplus}, 1;
                $cv->end;
            }
        } );

        $cv->wait;
    };
};

test_pocketio $server, $client;

ok(1, 'test done');

done_testing;

