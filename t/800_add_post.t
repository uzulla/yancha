use strict;
use warnings;
use PocketIO::Test;
use t::Utils;
use Test::More;
use AnyEvent;
use Yairc;
use Yairc::Client;
use Yairc::DataStorage::DBI;
use utf8;

use Data::Dumper;

BEGIN {
    use Test::More;
    plan skip_all => 'Test::mysqld and PocketIO::Client::IO is required to run this test'
      unless eval { require Test::mysqld; require PocketIO::Client::IO; 1 };
}

sub text2post {
    my ( $text ) = @_;
    my @tags = Yairc->extract_tags_from_text( $text );

    if ( @tags == 0 ){
        $text = $text . " #PUBLIC";
        push( @tags, "PUBLIC" );
    }

    return { text => $text, tags => [ @tags ] };
}


my $mysqld  = t::Utils->setup_mysqld( schema => './db/init.sql' );
my $config = { database => { connect_info => [ $mysqld->dsn ] } };
my $server = t::Utils->server_with_dbi( config => $config );
my $storage = Yairc::DataStorage::DBI->connect( connect_info => [ $mysqld->dsn ] );

my $ua = LWP::UserAgent->new;
my $port;
sub post_by_api {
    my ( $token, $text, $port ) = @_;
    my $req = POST("http://localhost:$port/api/post", { token => $token, text => $text });
    my $res = $ua->request( $req );

    return $res->status_line;
}

my $client = sub {
    $port = shift;
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

        $socket->on('nicknames', sub {
            is( $_[1]->{ test_client }, 'test_client', 'token login' );
            $cv->send;
        });

        $socket->emit('token login', $self->token);

        is ( post_by_api( $self->token, "Hello World. #public", $port ), 200 );
        is ( post_by_api( $self->token, "Hello world. #test", $port ), 200 );
        is ( post_by_api( $self->token, "Hello Perl.", $port ), 200 );
        is ( post_by_api( $self->token, <<TEXT, $port ), 200 );
あいう
えお
TEXT

    });

    $cv->wait;

};

test_pocketio $server, $client;

is( $storage->count_post, 4 );

my $posts = $storage->search_post( { text => [qw/Hello world./] } );
is( scalar(@$posts), 2 );

$posts = $storage->search_post( { tags => ['#public'] } );
is( scalar(@$posts), 3 );

$posts = $storage->search_post( { text => [qw/あいうえお/], tags => ['#test'] } );
is( scalar(@$posts), 1 );
done_testing;

