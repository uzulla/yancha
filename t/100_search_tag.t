use strict;
use warnings;
use t::Utils;
use Data::Dumper;
use Yairc;
use Yairc::DataStorage::DBI;


BEGIN {
    use Test::More;
    plan skip_all => 'Test::mysqld is required to run this test'
      unless eval { require Test::mysqld; 1 };
}

sub text2post {
    my ( $text ) = @_;
    my @tags = Yairc->build_tag_list_from_text( $text );

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
$storage->add_post( text2post( "foobar #tokyototyou" ), $user );
$storage->add_post( text2post( "foobar #tokyoto" ), $user );
$storage->add_post( text2post( "foobar #tokyoeki" ), $user );
$storage->add_post( text2post( <<TEXT ), $user );
タグの最大値は10 #tag1 #tag2 #tag3 #tag4 #tag5
#tag6 #
taghoge #tag7 #tag8 #tag9 #tag10 #tag11
TEXT

is( $storage->count_post, 7 );

my $posts = $storage->search_post( { tag => [qw/public/] } );
is( scalar(@$posts), 1 );

$posts = $storage->search_post( { tag => [qw/foo/] } );
is( scalar(@$posts), 2 );

$posts = $storage->search_post( { tag => [qw/bar/] } );
is( scalar(@$posts), 1 );

$posts = $storage->search_post( { tag => [qw/bar foo/] } );
is( scalar(@$posts), 2 );

$posts = $storage->search_post( { tag => [qw/tokyototyou/] } );
is( scalar(@$posts), 1 );
$posts = $storage->search_post( { tag => [qw/tokyoto/] } );
is( scalar(@$posts), 2, 'zenpoitti' );
$posts = $storage->search_post( { tag => [qw/tokyoeki/] } );
is( scalar(@$posts), 1 );

done_testing;

