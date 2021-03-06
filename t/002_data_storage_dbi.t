use strict;
use warnings;
use t::Utils;
use Data::Dumper;
use Test::More;

BEGIN {
    use_ok('Yancha::DataStorage::DBI');
}

my $testdb  = t::Utils->setup_testdb( schema => './db/init.sql' );
my $storage = Yancha::DataStorage::DBI->connect( connect_info => [ $testdb->dsn() ] );

isa_ok( $storage, 'Yancha::DataStorage::DBI' );

ok( my $user = $storage->add_user({
    user_key => '-:0001',
    nickname => 'user1',
    token    => '123456',
    profile_image_url => '',
    sns_data_cache    => '',
    profile_url       => 'https://twitter.com/#!/user1',
}) );

is( $storage->get_user_by_userkey( $user->{ user_key } )->{ user_key }, $user->{ user_key } );
is( $storage->get_user_by_token( $user->{ token } )->{ user_key }, $user->{ user_key } );

ok( my $user2 = $storage->add_user({
    user_key => '-:0002',
    nickname => 'user2',
    token    => '10101010',
    profile_image_url => '',
    sns_data_cache    => '',
    profile_url       => 'https://twitter.com/#!/user2',
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

is( $storage->get_user_by_userkey( $user->{ user_key } )->{ nickname }, $user->{ nickname } );

$user->{nick} = 'user1_modified';

is( $storage->count_user, 2 );
my $token = $user->{ token };
$user->{ token } = 'aaaaa';

ok( $storage->add_or_replace_user( $user ), 'add_or_replace_user' );




my $token2 = 'ABC123';
ok($storage->add_session($user, $token2), 'add_session');
my ($rows) = $storage->dbh->selectrow_array('SELECT count(*) FROM `session` WHERE `token` = ? ', {}, $token2);
is($rows, 1, 'add_session success');

my $session = $storage->get_session_by_token($token2);
#print Dumper($session);
is($session->{user_key}, $user->{user_key}, 'compare session' );

is($storage->get_user_by_token('EVER_NOT_MATCH_TOKEN'), undef, 'fake token session check');

my $ten_sec_before = (ref($testdb) =~ /\bSQLite$/) ?
                            "strftime('%s', 'now', '-10 seconds')" : 'now()-10';
$storage->dbh->do(qq{INSERT INTO `session` (`user_key`, `token`, `expire_at`) VALUES ('session_expire_user_key', 'session_expire_token', $ten_sec_before) }, {}) or die $storage->dbh->errstr;
ok($storage->clear_expired_session(), 'clear_expired_session');

($rows) = $storage->dbh->selectrow_array('SELECT count(*) FROM `session` WHERE `token` = ? ', {}, 'session_expire_token');
is($rows, 0, 'clean_expire_session');


is( $storage->count_user, 2 );


ok( my $post = $storage->add_post( { text => "Hello World. #PUBLIC", tags => ['PUBLIC'] }, $user ) );
is( $storage->count_post, 1 );
is( $post->{ id }, 1 );
is( $post->{ text }, "Hello World. #PUBLIC" );
is( $post->{ user_key }, '-:0001' );
is( $post->{ nickname }, 'user1' );
is( $post->{ plusplus }, 0 );
is_deeply( $post->{ tags }, ['PUBLIC'] );

$post->{ text } = 'HOGE #PUBLIC';
ok( $storage->replace_post( $post ) );
is( $storage->count_post, 1 );
is( $post->{ id }, 1 );
is( $post->{ text }, "HOGE #PUBLIC" );
is( $post->{ user_key }, '-:0001' );
is( $post->{ nickname }, 'user1' );
is( $post->{ plusplus }, 0 );

ok( $storage->remove_post( $post ) );
is( $storage->count_post, 0 );

my $lastusec = $storage->_get_now_micro_sec();

for my $i (  1 .. 100 ) {
    my $tag = $i % 2 ? 'ABC' : 'DEF';
    $storage->add_post( { text => "$i \#$tag", tags => [ $tag ] }, $user2 );
}

is( $storage->count_post, 100 );

my $posts = $storage->get_last_posts_by_tag( 'ABC', $lastusec );
is( scalar @$posts, 50 );
like( $posts->[0]->{ text }, qr/ #ABC/ );
$posts = $storage->get_last_posts_by_tag( 'DEF', $lastusec, 10 );
is( scalar @$posts, 10 );
like( $posts->[0]->{ text }, qr/ #DEF/ );

$posts = $storage->search_post( { tag => 'DEF' } );
is( scalar(@$posts), 50 );

$posts = $storage->search_post( { tag => ['ABC'] } );
is( scalar(@$posts), 50 );

$posts = $storage->search_post( { tag => ['ABC', 'DEF'] } );
is( scalar(@$posts), 100 );

$posts = $storage->search_post();
is( scalar(@$posts), 100 );

my $micro = $storage->_get_now_micro_sec;

$posts = $storage->search_post( { created_at_ms => [ $micro + 10000000 ] } );
is( scalar(@$posts), 0 );

$posts = $storage->search_post( { created_at_ms => [ undef, $micro ] } );
is( scalar(@$posts), 100 );

$posts = $storage->search_post( { tag => 'ABC', created_at_ms
                                    => [ $micro - 10000000, $micro + 10000000 ] } );
is( scalar(@$posts), 50 );

$posts = $storage->search_post(
    { tag => 'ABC', created_at_ms => [ $micro - 10000000, $micro + 10000000 ] },
    { limit => 10, offset => '5' }
);
is( scalar(@$posts), 10 );

{
    my $add_post = $storage->add_post( { text => "aa \#ABC", tags => ['ABC'] }, $user2 );
    my $post_by_id = $storage->get_post_by_id( $add_post->{id} );

    is( $add_post->{ id }, $post_by_id->{id} );
    is_deeply( $add_post->{ tags }, ['ABC'] );
}

subtest 'plusplus' => sub {
    my $temp_id = 10;
    {
        ok( $storage->plusplus($temp_id) );
        my $temp = $storage->get_post_by_id($temp_id);
        is $temp->{plusplus}, 1;
    }

    {
        ok( $storage->plusplus($temp_id) );
        my $temp = $storage->get_post_by_id($temp_id);
        is $temp->{plusplus}, 2;
    }
};

done_testing;

