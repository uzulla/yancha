use strict;
use warnings;
use utf8;
use PocketIO::Test;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use JSON;
use Test::More;
use Yancha;
use Yancha::Client;
use Yancha::DataStorage::DBI;
use t::Utils;

BEGIN {
    use Test::More;
    plan skip_all => 'PocketIO::Client::IO are required to run this test'
      unless eval { require PocketIO::Client::IO; 1 };
}

sub text2post {
    my ( $text, $created_at_ms ) = @_;
    my @tags = Yancha->extract_tags_from_text( $text );
    $created_at_ms = Yancha::DataStorage->_get_now_micro_sec() unless $created_at_ms;

    if ( @tags == 0 ){
        $text = $text . " #PUBLIC";
        push( @tags, "PUBLIC" );
    }

    return { text => $text, tags => [ @tags ], created_at_ms => $created_at_ms };
}

my $user = {
    user_key => '-:0001',
    nickname => 'user',
    token    => '10101010',
    profile_image_url => '',
    profile_url       => '',
    sns_data_cache    => '',
};

my $testdb  = t::Utils->setup_testdb(schema => './db/init.sql');
my $storage = Yancha::DataStorage::DBI->connect(
    connect_info => [$testdb->dsn]
);

my %post_messages = (
    111222333444111 => 'Hello World. #public',
    111222333444222 => '#foo foo',
    111222333444333 => '#foo foobar #bar',
    111222333444555 => 'あいうえお',
    111222333444666 => 'あい',
    111222333444777 => 'Hello Perl.',
    111222333444888 => 'あいう えお',
);

for my$created_at_ms ( keys %post_messages ) {
    $storage->add_post( text2post( $post_messages{$created_at_ms}, $created_at_ms ), $user );
}
is( $storage->count_post, 7 );

my $config = {
    database => {connect_info => [$testdb->dsn]},
    server_info => {
        api_endpoint => {
            '/api/search' => ['Yancha::API::Search', {}, 'For testing'],
        }
    },
};
my $server = t::Utils->server_with_dbi(config => $config);

test_pocketio $server => sub {
    my ($port) = @_;
    my $client = Yancha::Client->new;

    my $ua = LWP::UserAgent->new;
    my $search_by_api = sub {
        my ($param) = @_;
        my $limit = defined($param->{'limit'}) ? $param->{'limit'} : 20 ;

        my $req = POST "http://localhost:$port/api/search" => {
            'limit' => $limit
        };
        my $content = JSON::from_json($ua->request($req)->content);

        return $content ? $content : [];
    };

    is ( scalar( @{$search_by_api->()} ), 7 );

    my $posts = $search_by_api->( { 'limit' => '5' } );
    is (scalar(@$posts), 5 );

    $posts = $search_by_api->( { 'limit' => '3,4' } );
    is (scalar(@$posts), 3 );

};


done_testing;
