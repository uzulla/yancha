package Yairc::API::Search;

use strict;
use warnings;
use Yairc::API;
use parent qw(Yairc::API);

our $VERSION = '0.01';


sub search {
    my ( $self, $req ) = @_;
    my $where = {};
    my $attr  = {};

    if ( my $limit_param = $req->param('limit') ) {
        @{ $attr }{ qw/limit offset/ } = split /\s*,\s*/, $limit_param, 2;
    }

    if ( my $tags = $req->param('tag') ) {
        $where->{ tag } = [ split /,/, $tags ];
    }

    if ( my $times = $req->param('time') ) { # epoch sec
        $where->{ created_at_ms } = [ split /,/, $times ];
    }

    my $posts = $self->data_storage->search_post( $where, $attr );

    my $format = $req->param('t') || 'json';

    if ( $format eq 'text' ) {
        return $self->response_as_text( $posts );
    }
    else {
        return $self->response_as_json( $posts );
    }

}


1;
