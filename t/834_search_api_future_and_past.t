use strict;
use warnings;
use utf8;
use PocketIO::Test;
use LWP::UserAgent;
use HTTP::Request::Common qw(GET POST);
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
    111222333111000 => 'Hello World. #public',
    111222333222000 => '#foo foo',
    111222333444000 => '#foo foobar #bar',
    111222333555000 => 'あいうえお',
    111222333666000 => 'あい',
    111222333777000 => 'Hello Perl.',
    111222333888000 => 'あいう えお',
);

for my$created_at_ms( keys %post_messages ) {
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

        my $key = defined($param->{older}) ? 'older' : 'newer';

        my $req = POST "http://localhost:$port/api/search" => {
            "time" => $param->{'time'},
            "$key" => $param->{$key},
        };
        my $content = JSON::from_json($ua->request($req)->content);

        return $content ? $content : [];
    };

    is ( scalar( @{$search_by_api->( { 'older' => 7 } )} ), 7 );

    my $time = 1112223335;
    my $posts = $search_by_api->( { 'time' => "$time", 'older' => 3 } );
    is (scalar(@$posts), 3 );
    for my$post( @{$posts} ) {
        ok( $post->{created_at_ms}<$time*100000 );
    }

    $posts = $search_by_api->( { 'older' => 4 } );
    is (scalar(@$posts), 4 );

    is ( scalar( @{$search_by_api->( { newer => 7 } )} ), 7 );

    $posts = $search_by_api->( { 'newer' => 4 } );
    is (scalar(@$posts), 4 );

    $time = 1112223334;
    $posts = $search_by_api->( { 'time' => $time, 'newer' => 2 } );
    is (scalar(@$posts), 2 );
    for my$post( @$posts ) {
        ok( $post->{created_at_ms} > $time*100000 );
    }


};


done_testing;
