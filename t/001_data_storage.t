use strict;
use warnings;

use Test::More;

BEGIN {
    use_ok('Yancha::DataStorage::Mock');
}

my $add_user_param = {
    user_key => '-:0001',
    nickname => 'user1',
    token    => '123456',
    profile_image_url => '',
    sns_data_cache    => '',
};

my $add_user2_param = {
    user_key => '-:0002',
    nickname => 'user2',
    token    => '10101010',
    profile_image_url => '',
    sns_data_cache    => '',
};

subtest add_user => sub {

    my $storage = Yancha::DataStorage::Mock->new();
    ok( my $user = $storage->add_user($add_user_param) );


    is_deeply( $storage->get_user_by_userkey( $user->{ user_key } ), $user );
    is_deeply( $storage->get_user_by_token(   $user->{ token } ),    $user );
};

subtest add_user2 => sub {

    my $storage = Yancha::DataStorage::Mock->new();
    my $user    = $storage->add_user($add_user_param);

    ok( my $user2 = $storage->add_user($add_user2_param) );
    is( $storage->count_user, 2 );
};


subtest replace_user => sub {

    my $storage = Yancha::DataStorage::Mock->new();
    my $user    = $storage->add_user($add_user_param);
    my $new_token = '78910';
    $user->{ token } = $new_token;

    ok( $storage->replace_user( $user ), 'replace_user' );
    is_deeply(
        $storage->get_user_by_token({ token => $new_token }),
        $user
    );
};

subtest remove_user => sub {

    my $storage = Yancha::DataStorage::Mock->new();
    my $user    = $storage->add_user($add_user_param);

    ok( $storage->remove_user( $user ), 'remove_user' );

    is( $storage->get_user_by_userkey( $user->{ user_key } ), undef, 'removed' );

    ok( !$storage->replace_user( $user ), 'replace_user but no data' );

    is( $storage->count_user, 0 );
};

subtest add_or_replace_user_when_non_exists_user => sub {

    my $storage = Yancha::DataStorage::Mock->new();

    ok( my $user = $storage->add_or_replace_user( $add_user_param ), 'add_or_replace_user' );

    is_deeply( $storage->get_user_by_userkey( $user->{ user_key } ), $user );

    $user->{nick} = 'user1_modified';

    is( $storage->count_user, 1 );
};

subtest add_or_replace_user_when_exists_user => sub {

    my $storage = Yancha::DataStorage::Mock->new();
    my $user    = $storage->add_user($add_user_param);
    my $new_token = '78910';
    $user->{ token } = $new_token;

    ok( $storage->add_or_replace_user($user), 'add_or_replace_user' );

    is_deeply(
        $storage->get_user_by_token({ token => $new_token }),
        $user
    );

    is( $storage->count_user, 1 );
};

subtest add_post => sub {

    my $storage = Yancha::DataStorage::Mock->new();
    my $user    = $storage->add_user($add_user_param);

    ok( my $post = $storage->add_post( { text => "Hello World. #PUBLIC" }, $user ) );
    is( $storage->count_post, 1 );
    is( $post->{ text }, "Hello World. #PUBLIC" );
    is( $post->{ user_key }, '-:0001' );
    is( $post->{ nickname }, 'user1' );
};

subtest remove_post => sub {

    my $storage = Yancha::DataStorage::Mock->new();
    my $user    = $storage->add_user($add_user_param);
    my $post    = $storage->add_post( { text => "Hello World. #PUBLIC" }, $user );

    ok( $storage->remove_post( $post ) );
    is( $storage->count_post, 0 );
};

subtest multi_post => sub {

    my $storage = Yancha::DataStorage::Mock->new();
    my $user   = $storage->add_user($add_user_param);

    for my $i (1 .. 100) {
        $storage->add_post( { text => "$i" }, $user );
    }

    is( $storage->count_post, 100 );

    my $post = $storage->get_post_by_id( 10 );
    is( $post->{id}, 10 );

};

subtest post_tag => sub {
    my $storage = Yancha::DataStorage::Mock->new();
    my $user    = $storage->add_user($add_user_param);

    for my $i (  1 .. 100 ) {
        my $tag = $i % 2 ? '#ABC' : '#DEF';
        $storage->add_post( { text => "$i $tag" }, $user );
    }

    my $get_posts_by_tag;
    $get_posts_by_tag = $storage->get_last_posts_by_tag( 'ABC', 0 );
    is( scalar @$get_posts_by_tag, 50 );
    like( $get_posts_by_tag->[0]->{ text }, qr/ #ABC/ );


    $get_posts_by_tag = $storage->get_last_posts_by_tag( 'DEF', 0, 10 );
    is( scalar @$get_posts_by_tag, 10 );

    like( $get_posts_by_tag->[0]->{ text }, qr/ #DEF/ );

};

done_testing;

__END__
