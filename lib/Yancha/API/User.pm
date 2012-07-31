package Yancha::API::User;

use strict;
use warnings;
use utf8;
use Yancha::API;
use parent qw(Yancha::API);

our $VERSION = '0.01';

sub run {
    my ( $self, $req ) = @_;
    
    my $users = [];
    my %tmp_users;
    for my$user( values %{ $self->sys->users } ) {
        next if (exists($tmp_users{ $user->{ user_key } }));
        $tmp_users{ $user->{ user_key } } = 1;
        push(@$users, $user);
    }

    return $self->response_as_json( $users );
}

1;
