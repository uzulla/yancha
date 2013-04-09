#!perl

use strict;
use warnings;
use utf8;
use AnyEvent;
use HTTP::Request::Common qw/GET/;
use JSON;
use LWP::UserAgent;
use PocketIO::Test;
use Yancha::Client;
use t::Utils;

BEGIN {
    use Test::More;
    plan skip_all => 'PocketIO::Client::IO are required to run this test'
      unless eval { require PocketIO::Client::IO; 1 };
}

my $testdb = t::Utils->setup_testdb( schema => './db/init.sql' );
my $config = {
    database    => { connect_info => [ $testdb->dsn ] },
    server_info => {
        api_endpoint => {
            '/api/user' => [ 'Yancha::API::User', {}, 'For testing' ],
        }
    },
};
my $server = t::Utils->server_with_dbi( config => $config );

test_pocketio $server, sub {
    my ($port) = shift;
    t::Utils->create_clients_and_set_tags(
        $port,
        { nickname => 'John' },
        { nickname => 'Paul' },
        { nickname => 'Ringo' },
        { nickname => 'George' },
    );

    my $ua       = LWP::UserAgent->new;
    my $req      = GET "http://localhost:$port/api/user";
    my $response = $ua->request($req);
    my $contents = JSON::from_json( $response->content );

    my @expected_names = ( 'John', 'Paul', 'Ringo', 'George' );
    foreach my $content ( @{$contents} ) {
        my $got_name = $content->{'nickname'};
        @expected_names = grep( !/$got_name/, @expected_names );
    }

    is scalar @expected_names, 0, 'Response contains the all users info.';
};

done_testing;
