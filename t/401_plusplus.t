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
my $config = {
    database => { connect_info => [ $mysqld->dsn ] },
};

my $data_storage = Yairc::DataStorage::DBI->connect( %{$config->{database}} );
$data_storage->add_post( { text => "makamaka #PUBLIC", tags => [ 'PUBLIC' ] }, {
    nickname => 'user', user_key => '-:0001', profile_image_url => '',
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

