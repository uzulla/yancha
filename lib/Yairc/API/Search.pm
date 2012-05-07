package Yairc::API::Search;

use strict;
use warnings;
use Yairc::API;
use parent qw(Yairc::API);

our $VERSION = '0.01';


sub search {
    my ( $self, $req ) = @_;
    my $posts;

    if ( my $id = $req->param('id') ) {
        $id = 0 unless $id =~ /^[0-9]+$/;
        $posts = $self->data_storage->get_post_by_id( $id );
    }
    else {
        $posts = $self->_search_posts( $req );
    }

    my $format = $req->param('t') || 'json';

    if ( $format eq 'text' ) {
        return $self->response_as_text( ref $posts eq 'ARRAY' ? $posts : [ $posts ] );
    }
    else {
        return $self->response_as_json( $posts );
    }
}

sub _search_posts {
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

    return $self->data_storage->search_post( $where, $attr );
}


1;
