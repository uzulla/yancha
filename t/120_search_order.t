use strict;
use warnings;
use t::Utils;
use Data::Dumper;
use Test::More;
use Yancha;
use Yancha::Client;
use Yancha::DataStorage::DBI;
use HTTP::Request::Common qw/GET/;
use PocketIO::Test;
use JSON;
use utf8;

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


my $testdb  = t::Utils->setup_testdb( schema => './db/init.sql' );
my $storage = Yancha::DataStorage::DBI->connect( connect_info => [ $testdb->dsn() ] );

my $user = {
    user_key => '-:0001',
    nickname => 'user',
    token    => '10101010',
    profile_image_url => '',
    profile_url       => '',
    sns_data_cache    => '',
};


my %plusplus_values = (
    # $message => $plusplus_count,
    'message 1 #PUBLIC' => 2,
    'message 2 #PUBLIC' => 50,
    'message 3 #PUBLIC' => 10,
    'message 4 #PUBLIC' => 12,
    'message 5 #PUBLIC' => 0,
    'message 6 #PUBLIC' => 8,
    'message 7 #PUBLIC' => 7,
);

for my$msg( keys %plusplus_values ) {
    $storage->add_post( text2post( $msg ), $user );
}

is( $storage->count_post, 7 );

my $posts = $storage->search_post();
is( scalar(@$posts), 7 );
for my$post ( @{$posts} ) {
    #is( $post->{text},  );
    $storage->plusplus( $post->{id} ) for 1..$plusplus_values{"$post->{text}"};
}


$posts = $storage->search_post( {}, { order_by => 'plusplus ASC' });
my $i = 0;
for my$msg( sort { $plusplus_values{$a} <=> $plusplus_values{$b} } keys %plusplus_values ) {
    is( $msg, $posts->[$i++]->{text} );
}

$posts = $storage->search_post( {}, { order_by => 'plusplus DESC' });
$i = 0;
for my$msg( sort { $plusplus_values{$b} <=> $plusplus_values{$a} } keys %plusplus_values ) {
    is( $msg, $posts->[$i++]->{text} );
}




my $config = {
    database => {connect_info => [$testdb->dsn]},
    server_info => {
        name => 'TEST ORDER SEARCH',
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
        my ($query) = @_;
        my @qs;
        push( @qs, "$_=$query->{$_}" ) for ( keys %{$query} );
        my $query_string = (@qs) ? '?'.join('&', @qs) : '';

        my $req = GET "http://localhost:$port/api/search$query_string";
        my $res = $ua->request( $req );
        return JSON::from_json( $res->content );
    };
    my $posts;

    $posts = $search_by_api->( { order => 'plusplus' } );
    my $i = 0;
    for my$msg( sort { $plusplus_values{$a} <=> $plusplus_values{$b} } keys %plusplus_values ) {
        is( $msg, $posts->[$i++]->{text} );
    }

    $posts = $search_by_api->( { order => '-plusplus' } );
    $i = 0;
    for my$msg( sort { $plusplus_values{$b} <=> $plusplus_values{$a} } keys %plusplus_values ) {
        is( $msg, $posts->[$i++]->{text} );
    }


};

done_testing;

