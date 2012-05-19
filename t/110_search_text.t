use strict;
use warnings;
use t::Utils;
use Data::Dumper;
use Yairc;
use Yairc::DataStorage::DBI;
use utf8;

BEGIN {
    use Test::More;
    plan skip_all => 'Test::mysqld is required to run this test'
      unless eval { require Test::mysqld; 1 };
}

sub text2post {
    my ( $text ) = @_;
    my @tags = Yairc->extract_tags_from_text( $text );

    if ( @tags == 0 ){
        $text = $text . " #PUBLIC";
        push( @tags, "PUBLIC" );
    }

    return { text => $text, tags => [ @tags ] };
}


my $mysqld  = t::Utils->setup_mysqld( schema => './db/init.sql' );
my $storage = Yairc::DataStorage::DBI->connect( connect_info => [ $mysqld->dsn() ] );

my $user = {
    user_key => '-:0001',
    nickname => 'user',
    token    => '10101010',
    profile_image_url => '',
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

