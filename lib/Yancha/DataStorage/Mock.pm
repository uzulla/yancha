package Yancha::DataStorage::Mock;

use strict;
use warnings;
use base 'Yancha::DataStorage';

our $VERSION = '0.01';

sub users {
    my ($self,$user) = @_;
    if ($user) {
        my $users = $self->{users};
        push @$users, $user;
        $self->{users} = $users;
    }
    return  @{ $self->{users} || [] };
}

sub user {
    my ($self,$key,$user) = @_;

    if( $key && $user) {
        $self->{user}->{$key} = $user;
    }
    return $self->{user}->{$key};
}

sub user_token {
    my ($self,$token,$user) = @_;
    if( $token && $user) {
        $self->{user_token}->{$token} = $user;
    }
    return $self->{user_token}->{$token};
}


sub add_user {
    my ($self, $user) = @_;

    $self->users($user);
    $self->user( $user->{ user_key }, $user);
    $self->user_token( $user->{ token }, $user);
    return $user;
}

sub get_user_by_userkey {
    my ( $self, $user ) = @_;
    my $userkey = ref $user ? $user->{ user_key } : $user;
    return $self->user( $userkey );
}

sub get_user_by_token {
    my ( $self, $user ) = @_;
    my $token = ref $user ? $user->{ token } : $user;
    return $self->user_token( $token );
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
    $self->{users} = [ grep { $_->{user_key} ne $userkey } $self->users ];
    delete $self->{user_token}->{ $user->{token} };
    return delete $self->{user}->{$userkey};
}

sub count_user {
    my $self = shift;
    return scalar $self->users;
}

sub posts {
    my ($self,$post) = @_;
    if ($post) {
        my $posts = $self->{posts};
        push @$posts, $post;
        $self->{posts} = $posts;
    }
    return  @{ $self->{posts} || [] };
}

sub post {
    my ($self,$id,$post) = @_;

    if( $id && $post) {
        $self->{post}->{$id} = $post;
    }
    return $self->{post}->{$id};
}

sub _id{
    my $self = shift;
    ++$self->{id};
}

sub add_post {
    my ( $self, $post, $user ) = @_;
    $post = $user ? {
        id   => $self->_id(),
        text => $post->{ text },
        nickname => $user->{ nickname },
        user_key => $user->{ user_key },
        profile_image_url => $user->{ profile_image_url },
        created_at_ms     => $self->_get_now_micro_sec(),
    } : { %$post, id => $self->_id(), created_at_ms => $self->_get_now_micro_sec() };
    $self->posts($post);
    $self->post($post->{id}, $post);
    return $post;
}

sub remove_post {
    my ( $self, $post ) = @_;
    my $id = $post->{id};
    $self->{posts} = [grep { $_->{id} ne $id } $self->posts ];

    return delete $self->{post}->{ $post->{id} };
}

sub get_last_posts_by_tag {
    my ( $self, $tag, $lastusec, $num ) = @_;
    $tag = uc($tag);
    my @posts = grep { $_->{ text } =~ /\s+#${tag}\s*/ }
                reverse sort { $a->{ created_at_ms } <=> $b->{ created_at_ms } } $self->posts;
 
    return $num ? [ @posts[ 0 .. $num - 1 ] ] : \@posts;
}

sub get_post_by_id {
    my ( $self, $id ) = @_;
    return $self->post($id);
}

sub count_post { scalar $_[0]->posts }



1;
__END__
