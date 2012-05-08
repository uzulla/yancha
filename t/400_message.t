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
    my ( $client1, $client2 ) = t::Utils->create_clients_and_set_tags(
        $port,
        { nickname => 'client1', tags => ['hoge'] }, 
        { nickname => 'client2' }, # default tag is public
    );

    my $cv = AnyEvent->condvar;
    my $w  = AnyEvent->timer( after => 15, cb => sub {
        fail("Time out.");
        $cv->end; $cv->end;
    } );

    $cv->begin; $cv->begin;
        
    $client1->socket->on('user message', sub {
        my $post = $_[1];
        is( $post->{ text }, "Hello Hachioji.pm #HOGE", 'c1 : ' . $post->{ text } );
        is( $post->{ nickname }, "client2" );
        $cv->end;
    });

    $client2->socket->on('user message', sub {
        my $post = $_[1];
        is( $post->{ text }, "Hello Hachioji.pm #PUBLIC", 'c2 : ' . $post->{ text } );
        is( $post->{ nickname }, "client1" );
        $cv->end;
    });

    $client1->socket->emit('user message', "Hello Hachioji.pm");
    $client2->socket->emit('user message', "Hello Hachioji.pm #HOGE");

    $cv->wait;
};

test_pocketio $server, $client;

ok(1, 'test done');

done_testing;

