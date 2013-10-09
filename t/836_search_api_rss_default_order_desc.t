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
            '/api/post'   => ['Yancha::API::Post',   {}, 'For testing'],
            '/api/search' => ['Yancha::API::Search', {}, 'For testing'],
        }
    },
};
my $server = t::Utils->server_with_dbi(config => $config);

test_pocketio $server => sub {
    my ($port) = @_;
    my $client = Yancha::Client->new;

    my $nick = 'test_client';

    $client->login(
        "http://localhost:$port/" => 'login', {nick => $nick}
    );
    my $ua = LWP::UserAgent->new;
    my $post_by_api = sub {
        my ($text) = @_;
        my $req = POST "http://localhost:$port/api/post" => {
            token => $client->token, text => $text
        };
        $ua->request($req)->code;
    };

    my @posts = (
        "Hello World. #PUBLIC",
        "Hello world. #PUBLIC",
        "Hello Perl. #PUBLIC",
    );
    
    for my$text( @posts ) {
        $post_by_api->($text);
    }

    my $req = GET "http://localhost:$port/api/search?t=rss";
    my $rss_res = $ua->request($req);
    
    is $rss_res->code => 200;

    my $xml = $rss_res->content;
    my $feed = XML::FeedPP->new( $xml );
    $feed->sort_item;

    my @items = $feed->get_item;
    my $post_count = scalar @posts;
    is scalar @items => $post_count;

    my $last_index = $post_count - 1;
    for my$i( 0..$last_index ) {
        is $items[$i]->description, $nick . " : " . $posts[$last_index-$i];
    }

};

done_testing;
