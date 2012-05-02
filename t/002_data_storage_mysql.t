use strict;
use warnings;
use Data::Dumper;

BEGIN {
    use Test::More;
    plan skip_all => 'Test::mysqld is required to run this test'
      unless eval { require Test::mysqld; 1 };
}

BEGIN {
    use_ok('Yairc::DataStorage::DBI::mysql');
}

my $mysqld = Test::mysqld->new(
    my_cnf => { 'skip-networking' => '' }
) or plan skip_all => $Test::mysqld::errstr;

my $dbh = DBI->connect( $mysqld->dsn() );

open( my $fh, '<', 'db/init.sql' ) or plan skip_al => "Can't open init.sql";

for my $lines ( split/;\n/, do { <$fh>; local $/; <$fh> } ) {
    $dbh->do( $lines );
}


my $storage = Yairc::DataStorage::DBI::mysql->new( dbh => $dbh );

diag('user');

ok( my $user = $storage->add_user({
    user_key => '-:0001',
    nickname => 'user1',
    token    => '123456',
    profile_image_url => '',
    sns_data_cache    => '',
}) );

is( $storage->get_user_by_userkey( $user->{ user_key } )->{ user_key }, $user->{ user_key } );
is( $storage->get_user_by_token( $user->{ token } )->{ user_key }, $user->{ user_key } );

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

is( $storage->get_user_by_userkey( $user->{ user_key } )->{ user_key }, $user->{ user_key } );

ok( $storage->remove_user( { user_key => '-:0001' } ), 'remove_user' );

is( $storage->get_user_by_userkey( $user->{ user_key } ), undef, 'removed' );

# return 0E0 !
ok( ! 0 + $storage->replace_user( $user ), 'replace_user but no data' );

is( $storage->count_user, 1 );

ok( $storage->add_or_replace_user( $user ), 'add_or_replace_user' );

is( $storage->get_user_by_userkey( $user->{ user_key } )->{ token }, $user->{ token } );

$user->{nick} = 'user1_modified';

is( $storage->count_user, 2 );

$user->{ token } = 'aaaaa';

ok( $storage->add_or_replace_user( $user ), 'add_or_replace_user' );

is( $storage->get_user_by_userkey( $user->{ user_key } )->{ token }, $user->{ token } );

is( $storage->count_user, 2 );


diag('post');

ok( my $post = $storage->add_post( { text => "Hello World. #PUBLIC" }, $user ) );
is( $storage->count_post, 1 );
is( $post->{ id }, 1 );
is( $post->{ text }, "Hello World. #PUBLIC" );
is( $post->{ user_key }, '-:0001' );
is( $post->{ nickname }, 'user1' );

ok( $storage->remove_post( $post ) );
is( $storage->count_post, 0 );

my $lastusec = $storage->_get_now_micro_sec();

for my $i (  1 .. 100 ) {
    my $tag = $i % 2 ? '#ABC' : '#DEF';
    $storage->add_post( { text => "$i $tag" }, $user2 );
}

is( $storage->count_post, 100 );

my $posts = $storage->get_last_posts_by_tag( 'ABC', $lastusec );
is( scalar @$posts, 50 );
like( $posts->[0]->{ text }, qr/ #ABC/ );
$posts = $storage->get_last_posts_by_tag( 'DEF', $lastusec, 10 );
is( scalar @$posts, 10 );
like( $posts->[0]->{ text }, qr/ #DEF/ );


done_testing;

