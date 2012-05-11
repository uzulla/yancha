use strict;
use warnings;
use PocketIO::Test;
use t::Utils;
use AnyEvent;
use Yairc::Client;
use Yairc::DataStorage::DBI;

BEGIN {
    use Test::More;
    plan skip_all => 'Test::mysqld and PocketIO::Client::IO are required to run this test'
      unless eval { require Test::mysqld; require PocketIO::Client::IO; 1 };
}

my $mysqld = t::Utils->setup_mysqld( schema => './db/init.sql' );
my $data_storage = Yairc::DataStorage::DBI->connect( connect_info => [ $mysqld->dsn ] );

my $user = {
    nickname => 'user', user_key => '-:0001', profile_image_url => '',
};

for my $i ( 1 .. 100 ) {
    my $tag = $i % 2 ? 'PUBLIC' : 'FOO';
    $data_storage->add_post( { text => "post $i #$tag", tags => [ $tag ] }, $user );
}


my $config = {
    database => { connect_info => [ $mysqld->dsn ] },
    message_log_limit => 20,
};
my $server = t::Utils->server_with_dbi( config => $config );

my $client = sub {
    my ( $port ) = shift;

    # TODO: 処理時間依存なのをなんとかする
    my $cv = AnyEvent->condvar;
    my $w  = AnyEvent->timer( after => 15, cb => sub {
        fail("Time out.");
        $cv->send;
    } );

    my $tag          = '';
    my $count_public = 0;
    my $count_foo    = 0;
    my $on_connect = sub {
        my ( $client ) = @_;

        $client->socket->on( 'user message', sub {
            my $post = $_[1];

            ok(1, $post->{ tags }->[0]);

            if ( $post->{ tags }->[0] eq 'PUBLIC' ) {
                $count_public++;
            }
            elsif ( $tag eq 'foo' and $post->{ tags }->[0] eq 'FOO' ) {
                $count_foo++;
            }

            $cv->send if $count_public == 20 and  $count_foo == 20;
        } );

    };

    my ( $client ) = t::Utils->create_clients_and_set_tags(
        $port,
        { nickname => 'client', on_connect => $on_connect }, 
    );

    my $timer = AnyEvent->timer( after => 5, cb => sub {
        $tag = 'foo';
        $client->socket->emit('join tag', { 'foo' => 'foo' });
    } );


    $cv->wait;
};

test_pocketio $server, $client;

ok(1, 'test done');

done_testing;

