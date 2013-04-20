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
    my ( $text ) = @_;
    my @tags = Yancha->extract_tags_from_text( $text );

    if ( @tags == 0 ){
        $text = $text . " #PUBLIC";
        push( @tags, "PUBLIC" );
    }

    return { text => $text, tags => [ @tags ] };
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

$storage->add_post( text2post( "Hello World. #public" ), $user );
$storage->add_post( text2post( "#foo foo" ), $user );
$storage->add_post( text2post( "#foo foobar #bar" ), $user );
$storage->add_post( text2post( "あいうえお" ), $user );
$storage->add_post( text2post( "あい" ), $user );
$storage->add_post( text2post( "Hello Perl." ), $user );
$storage->add_post( text2post( <<TEXT ), $user );
あいう
えお
TEXT

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
        my $keyword = defined($param->{text}) ? $param->{text} : '';

        my $req = POST "http://localhost:$port/api/search" => {
            keyword => $keyword
        };
        my $content = JSON::from_json($ua->request($req)->content);

        return $content ? $content : [];
    };

    is ( scalar( @{$search_by_api->()} ), 7 );

    my $posts = $search_by_api->( { text => 'Hello,World' } );
    is (scalar(@$posts), 1 );

    $posts = $search_by_api->( { text => 'Hello World' } );
    is (scalar(@$posts), 1 );

    $posts = $search_by_api->( { text => 'Hello' } );
    is (scalar(@$posts), 2 );

    $posts = $search_by_api->( { text => 'あい' } );
    is (scalar(@$posts), 3 );

    $posts = $search_by_api->( { text => 'あいうえお' } );
    is (scalar(@$posts), 1 );

    $posts = $search_by_api->( { text => 'あいう' } );
    is (scalar(@$posts), 2 );

    $posts = $search_by_api->( { text => '#PUBLIC' } );
    is (scalar(@$posts), 5 );

};


done_testing;
