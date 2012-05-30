package Yancha::DataStorage::Mock;

use strict;
use warnings;
use base 'Yancha::DataStorage';

our $VERSION = '0.01';

my @USERS;
my %USER;
my %USER_TOKEN;


sub add_user {
    push @USERS, $_[1];
    $USER{ $_[1]->{ user_key } } = $_[1];
    $USER_TOKEN{ $_[1]->{ token } } = $_[1];
    return $_[1];
}

sub get_user_by_userkey {
    my ( $self, $user ) = @_;
    my $userkey = ref $user ? $user->{ user_key } : $user;
    return $USER{ $userkey };
}

sub get_user_by_token {
    my ( $self, $user ) = @_;
    my $token = ref $user ? $user->{ token } : $user;
    return $USER_TOKEN{ $token };
}

sub replace_user {
    my ( $self, $user ) = @_;
    if ( $self->get_user_by_userkey( $user ) ) {
        $self->remove_user( $user );
        return $self->add_user( $user );
    }
    return;
}

sub add_or_replace_user {
    my ( $self, $user ) = @_;
    if ( $self->get_user_by_userkey( $user ) ) {
        $self->remove_user( $user );
    }
    $self->add_user( $user );
}

sub remove_user {
    my ( $self, $user ) = @_;
    my $userkey = $user->{ user_key };
    @USERS = grep { $_->{user_key} ne $userkey } @USERS;
    delete $USER_TOKEN{ $user->{ token } || '' };
    return delete $USER{ $userkey };
}

sub count_user {
    return scalar @USERS;
}


my @POSTS;
my %POST;
my $ID = 1;


sub _id{ $ID++; }

sub add_post {
    my ( $self, $post, $user ) = @_;
    $post = $user ? {
        id   => _id(),
        text => $post->{ text },
        nickname => $user->{ nickname },
        user_key => $user->{ user_key },
        profile_image_url => $user->{ profile_image_url },
        created_at_ms     => $self->_get_now_micro_sec(),
    } : { %$post, id => _id(), created_at_ms => $self->_get_now_micro_sec() };
    push @POSTS, $post;
    $POST{ $post->{ id } } = $post;
    return $post;
}

sub remove_post {
    my ( $self, $post ) = @_;
    my $id = $post->{ id };
    @POSTS = grep { $_->{id} ne $id } @POSTS;
    return delete $POST{ $post->{ id } };    
}

sub get_last_posts_by_tag {
    my ( $self, $tag, $lastusec, $num ) = @_;
    $tag = uc($tag);
    my @posts = grep { $_->{ text } =~ /\s+#${tag}\s*/ }
                reverse sort { $a->{ created_at_ms } <=> $b->{ created_at_ms } } @POSTS;
 
    return $num ? [ @posts[ 0 .. $num - 1 ] ] : \@posts;
}

sub get_post_by_id {
    my ( $self, $id ) = @_;
    return $POST{$id};
}

sub count_post { scalar @POSTS; }



1;
__END__
