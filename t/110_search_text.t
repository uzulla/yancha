use strict;
use warnings;
use t::Utils;
use Data::Dumper;
use Test::More;
use Yancha;
use Yancha::DataStorage::DBI;
use utf8;

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

is( $storage->count_post, 7 );

my $posts = $storage->search_post( { text => [qw/Hello World/] } );
is( scalar(@$posts), 1 );

$posts = $storage->search_post( { text => [qw/Hello/] } );
is( scalar(@$posts), 2 );

$posts = $storage->search_post( { text => [qw/あい/] } );
is( scalar(@$posts), 3 );

$posts = $storage->search_post( { text => [qw/あいうえお/] } );
is( scalar(@$posts), 1 );

$posts = $storage->search_post( { text => [qw/あいう/] } );
is( scalar(@$posts), 2 );

$posts = $storage->search_post( { text => ['#PUBLIC'] } );
is( scalar(@$posts), 5 );

done_testing;

