package Yancha::API::Tag;

use strict;
use warnings;
use utf8;
use Yancha::API;
use parent qw(Yancha::API);

our $VERSION = '0.01';

sub run {
    my ( $self, $req ) = @_;
 
    my $tags = $self->sys->data_storage->count_tags;

    return $self->response_as_json( $tags );
}

1;
