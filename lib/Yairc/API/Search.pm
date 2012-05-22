package Yairc::API::Search;

use strict;
use warnings;
use utf8;
use Yairc::API;
use parent qw(Yairc::API);
use Encode ();

our $VERSION = '0.01';


sub run {
    my ( $self, $req ) = @_;
    my $posts  = $self->_search_posts( $req );
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

    if ( my $keywords = $req->param('keyword') ) {
        $where->{ text } = [ grep { $_ ne '' } split(/[,\x20　]/, Encode::decode_utf8($keywords)) ];
    }

    if ( my $times = $req->param('time') ) { # epoch sec
        $where->{ created_at_ms } = [ map { $_ .= '00000' if defined; $_ } split /,/, $times ];
    }

    if ( my $ids = $req->param('id') ) {
        $where->{ id } = [ grep { $_ =~ /^[0-9]+$/ } split /,/, $ids ];
    }

    my $newer = $req->param('newer');
    my $older = $req->param('older');

    if ( $newer ) {
        $attr->{ limit } = $newer;
        delete $attr->{ offset };
        if ( ref $where->{ id } ) {
            $where->{ id } = $where->{ id }->[0];
            $where->{ id } = { '>' => $where->{ id } };
            $attr->{ order_by } = 'id ASC';
        }
        elsif ( ref $where->{ created_at_ms } ) {
            $where->{ created_at_ms } = { '>' => $where->{ created_at_ms }->[0] };
            $attr->{ order_by } = 'created_at_ms ASC';
        }
    }
    elsif ( $older ) {
        $attr->{ limit } = $older;
        delete $attr->{ offset };
        if ( ref $where->{ id } ) {
            $where->{ id } = $where->{ id }->[0];
            $where->{ id } = { '<' => $where->{ id } };
            $attr->{ order_by } = 'id DESC';
        }
        elsif ( ref $where->{ created_at_ms } ) {
            $where->{ created_at_ms } = { '<' => $where->{ created_at_ms }->[0] };
            $attr->{ order_by } = 'created_at_ms DESC';
        }
    }

    $attr->{ limit } ||= 20;

    return $self->sys->data_storage->search_post( $where, $attr );
}


1;
