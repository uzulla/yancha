use strict;
use warnings;
use utf8;
use Encode qw/encode_utf8/;
use PocketIO::Test;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use Test::More;
use Yancha::Client;
use Yancha::DataStorage::DBI;
use t::Utils;

BEGIN {
    use Test::More;
    plan skip_all => 'PocketIO::Client::IO are required to run this test'
      unless eval { require PocketIO::Client::IO; 1 };
}

my $testdb  = t::Utils->setup_testdb(schema => './db/init.sql');
my $config = {
    database => {connect_info => [$testdb->dsn]},
    server_info => {
        api_endpoint => {
            '/api/post' => ['Yancha::API::Post', {}, 'For testing'],
        }
    },
};
my $server = t::Utils->server_with_dbi(config => $config);

test_pocketio $server => sub {
    my ($port) = @_;
    my $client = Yancha::Client->new;

    ok $client->login(
        "http://localhost:$port/" => 'login', {nick => 'test_client'}
    ), 'login';

    my $ua = LWP::UserAgent->new;
    my $post_by_api = sub {
        my ($text) = @_;
        my $req = POST "http://localhost:$port/api/post" => {
            token => $client->token, text => encode_utf8 $text
        };
        $ua->request($req)->code;
    };

    is $post_by_api->("Hello World. #public"), 200;
    is $post_by_api->("Hello world."), 200;
    is $post_by_api->("Hello Perl."), 200;
    is $post_by_api->(<<TEXT), 200;
あいう
えお
 #test
TEXT
};

my $storage = Yancha::DataStorage::DBI->connect(
    connect_info => [$testdb->dsn]
);

is $storage->count_post => 4;

my $posts = $storage->search_post({text => [qw/Hello world./]});
is scalar @$posts => 2;

$posts = $storage->search_post({tag => ['public']});
is scalar @$posts => 3;

$posts = $storage->search_post({text => [qw/あいう/], tag => ['test']});
is scalar @$posts => 1;

done_testing;
