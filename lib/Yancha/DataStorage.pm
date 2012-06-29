package Yancha::DataStorage;

use strict;
use warnings;
use Time::HiRes qw/ time /;

our $VERSION = '0.01';

sub new {
    my $class = shift;
    my $self  = bless { @_ }, $class;
    $self->init() if $self->can('init');
    return $self;
}

sub _get_now_micro_sec {
    return Time::HiRes::time() * 100_000;
}

sub make_post {
    my ( $self, $data ) = @_;
    my $user = $data->{ user };

    return {
        text              => $data->{ text },
        nickname          => $user ? $user->{ nickname } : $data->{ nickname },
        user_key          => $user ? $user->{ user_key } : $data->{ user_key },
        profile_image_url => $user ? $user->{ profile_image_url } : $data->{ profile_image_url },
        profile_url       => $user ? $user->{ profile_url } : $data->{ profile_url },
        tags              => exists $data->{ tags} ? $data->{ tags } : [],
        plusplus          => exists $data->{ plusplus } ? $data->{ plusplus } : 0,
        created_at_ms     => exists $data->{ created_at_ms }
                                      ? $data->{ created_at_ms } : $self->_get_now_micro_sec(),
    };
}


1;
__END__

=pod

=head1 NAME

Yancha::DataStorage - data storage role class

=head1 USER DATA

=head1 POST DATA

=head1 METHODS

=head2 new

=head2 _init

=head2 add_user

=head2 remove_user

=head2 replace_user

=head2 add_or_replace_user

=head2 get_user_by_userkey

=head2 get_user_by_token

=head2 add_post

=head2 remove_post

=head2 get_last_posts_by_tag

=head2 _get_now_micro_sec

=cut

