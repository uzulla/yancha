use strict;
use warnings;
use utf8;
use PocketIO::Test;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST GET);
use Test::More;
use Yancha::Client;
use Yancha::DataStorage::DBI;
use XML::FeedPP;
use Data::Dumper;
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
        name => 'TEST RSS',
        api_endpoint => {
            '/api/post' => ['Yancha::API::Post', {}, 'For testing'],
            '/api/rss'  => ['Yancha::API::Rss',  {}, 'For testing'],
        }
    },
};
my $server = t::Utils->server_with_dbi(config => $config);

test_pocketio $server => sub {
    my ($port) = @_;
    my $client = Yancha::Client->new;

    $client->login(
        "http://localhost:$port/" => 'login', {nick => 'test_client'}
    );
    my $ua = LWP::UserAgent->new;
    my $post_by_api = sub {
        my ($text) = @_;
        my $req = POST "http://localhost:$port/api/post" => {
            token => $client->token, text => $text
        };
        $ua->request($req)->code;
    };
    $post_by_api->("Hello World. #public");
    $post_by_api->("Hello world.");
    $post_by_api->("Hello Perl.");

    my $req = GET "http://localhost:$port/api/rss";
    my $rss_res = $ua->request($req);
    
    is $rss_res->code => 200;

    my $xml = $rss_res->content;
    my $feed = XML::FeedPP->new( $xml );

    is $feed->title => 'yancha::TEST RSS';

    my @items = $feed->get_item;
    is scalar @items => 3;

};

done_testing;
