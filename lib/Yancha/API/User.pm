package Yancha::API::User;

use strict;
use warnings;
use utf8;
use Yancha::API;
use parent qw(Yancha::API);

our $VERSION = '0.01';

sub run {
    my ( $self, $req ) = @_;
    my $users = $self->sys->users;

    return $self->response_as_json( $users );
}

1;
