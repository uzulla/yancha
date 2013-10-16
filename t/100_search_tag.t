use strict;
use warnings;
use t::Utils;
use Data::Dumper;
use Yancha;
use Yancha::DataStorage::DBI;
use Test::More;

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
is( scalar(@$posts), 1, 'exact matching' );
$posts = $storage->search_post( { tag => [qw/tokyoeki/] } );
is( scalar(@$posts), 1 );

my $tag_counts = $storage->count_tags();

note explain $tag_counts;
is_deeply $tag_counts, +{
    BAR         => 1,
    FOO         => 2,
    TAG1        => 1,
    TAG10       => 1,
    TAG2        => 1,
    TAG3        => 1,
    TAG4        => 1,
    TAG5        => 1,
    TAG6        => 1,
    TAG7        => 1,
    TAG8        => 1,
    TAG9        => 1,
    TOKYOEKI    => 1,
    TOKYOTO     => 1,
    TOKYOTOTYOU => 1
};

done_testing;

