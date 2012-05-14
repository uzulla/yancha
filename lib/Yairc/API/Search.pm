package Yairc::API::Search;

use strict;
use warnings;
use Yairc::API;
use parent qw(Yairc::API);

our $VERSION = '0.01';


sub search {
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
        #TODO 全角スペースで単語を区切る
        $where->{ text } = [ grep { $_ ne '' } split(/[,\x20]/, $keywords) ];
    }

    if ( my $times = $req->param('time') ) { # epoch sec
        $where->{ created_at_ms } = [ split /,/, $times ];
    }

    if ( my $ids = $req->param('id') ) {
        $where->{ id } = [ grep { $_ =~ /^[0-9]+$/ } split /,/, $ids ];
    }

    if ( my $newer = $req->param('newer') ) {
        $attr->{ limit } = $newer;
        delete $attr->{ offset };
        $where->{ id } = $where->{ id }->[0] if ref $where->{ id };
        $where->{ id } = { '>' => $where->{ id } };
        $attr->{ order_by } = 'id ASC';
    }
    elsif ( my $older = $req->param('older') ) {
        $attr->{ limit } = $older;
        delete $attr->{ offset };
        $where->{ id } = $where->{ id }->[0] if ref $where->{ id };
        $where->{ id } = { '<' => $where->{ id } };
        $attr->{ order_by } = 'id DESC';
    }


    $attr->{ limit } ||= 20;

    return $self->data_storage->search_post( $where, $attr );
}


1;
