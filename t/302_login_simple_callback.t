use strict;
use warnings;
use PocketIO::Test;
use t::Utils;
use Yancha::Client;
use HTTP::Request::Common qw/GET/;
use LWP::UserAgent;

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
    my ( $port ) = shift;

    my $callback_url = "http://simple-login.test/callback";
    my $ua       = LWP::UserAgent->new;
    my $req      = GET "http://localhost:$port/login?callback_url=$callback_url&nick=tester&token_only=1";
    my $response = $ua->simple_request($req);

    ok( $response->is_redirect );

    my $location = $response->header( 'Location' );
    ok( $location =~ m/^$callback_url\?token=[a-zA-Z0-9]+$/ );

};


done_testing;


