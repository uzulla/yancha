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

my $user1 = {
    user_key => '-:0001',
    nickname => 'user1',
    token    => '101010101',
    profile_image_url => '',
    profile_url       => '',
    sns_data_cache    => '',
};

my $testdb  = t::Utils->setup_testdb(schema => './db/init.sql');
my $storage = Yancha::DataStorage::DBI->connect(
    connect_info => [$testdb->dsn]
);

$storage->add_post( text2post( "text1" ), $user1 );
$storage->add_post( text2post( "text2" ), $user1 );
$storage->add_post( text2post( "text3" ), $user1 );
$storage->add_post( text2post( "text4" ), $user1 );
$storage->add_post( text2post( "text5" ), $user1 );
$storage->add_post( text2post( "text6" ), $user1 );

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
        my ($param, $older_than_id) = @_;
        my $keyword = defined($param->{text}) ? $param->{text} : '';
        my $older_than_id = defined($param->{older_than_id}) ? $param->{older_than_id} : 9999; 

        my $req = POST "http://localhost:$port/api/search" => {
            keyword => $keyword,
	    older_than_id => $older_than_id
        };
        my $content = JSON::from_json($ua->request($req)->content);

        return $content ? $content : [];
    };

    is ( scalar( @{$search_by_api->()} ), 6 );

    my $posts = $search_by_api->( { text => '', older_than_id=> 4 } );
    is (scalar(@$posts), 3 );

    $posts = $search_by_api->( { text => '', older_than_id=>1 } );
    is (scalar(@$posts), 0 );

    $posts = $search_by_api->( { text => '' } );
    is (scalar(@$posts), 6 );

};


done_testing;
