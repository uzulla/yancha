use strict;
use warnings;

use Test::More;

BEGIN {
    use_ok('Yairc::DataStorage::Mock');
}


my $storage = Yairc::DataStorage::Mock->new();

ok( my $user = $storage->add_user({
    user_key => '-:0001',
    nickname => 'user1',
    token    => '123456',
    profile_image_url => '',
    sns_data_cache    => '',
}) );

is_deeply( $storage->get_user_by_userkey( $user->{ user_key } ), $user );
is_deeply( $storage->get_user_by_token( $user->{ token } ), $user );

ok( my $user2 = $storage->add_user({
    user_key => '-:0002',
    nickname => 'user2',
    token    => '10101010',
    profile_image_url => '',
    sns_data_cache    => '',
}) );

is( $storage->count_user, 2 );

$user->{ token } = '78910';

ok( $storage->replace_user( $user ), 'replace_user' );

is_deeply( $storage->get_user_by_userkey( $user->{ user_key } ), $user );

ok( $storage->remove_user( { user_key => '-:0001' } ), 'remove_user' );

is( $storage->get_user_by_userkey( $user->{ user_key } ), undef, 'removed' );

ok( !$storage->replace_user( $user ), 'replace_user but no data' );

is( $storage->count_user, 1 );

ok( $storage->add_or_replace_user( $user ), 'add_or_replace_user' );

is_deeply( $storage->get_user_by_userkey( $user->{ user_key } ), $user );

$user->{nick} = 'user1_modified';

is( $storage->count_user, 2 );

ok( $storage->add_or_replace_user( $user ), 'add_or_replace_user' );

is_deeply( $storage->get_user_by_userkey( $user->{ user_key } ), $user );

is( $storage->count_user, 2 );


ok( my $post = $storage->add_post( { text => "Hello World. #PUBLIC" }, $user ) );
is( $storage->count_post, 1 );
is( $post->{ text }, "Hello World. #PUBLIC" );
is( $post->{ user_key }, '-:0001' );
is( $post->{ nickname }, 'user1' );

ok( $storage->remove_post( $post ) );
is( $storage->count_post, 0 );

for my $i (  1 .. 100 ) {
    my $tag = $i % 2 ? '#ABC' : '#DEF';
    $storage->add_post( { text => "$i $tag" }, $user2 );
}

is( $storage->count_post, 100 );

my $posts = $storage->get_last_posts_by_tag( 'ABC', 0 );
is( scalar @$posts, 50 );
like( $posts->[0]->{ text }, qr/ #ABC/ );
$posts = $storage->get_last_posts_by_tag( 'DEF', 0, 10 );
is( scalar @$posts, 10 );
like( $posts->[0]->{ text }, qr/ #DEF/ );

$post = $storage->get_post_by_id( 10 );
is( $post->{id}, 10 );

done_testing;

