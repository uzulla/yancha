package Yancha::API::Search;

use strict;
use warnings;
use utf8;
use Yancha::API;
use parent qw(Yancha::API);
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


    my $attr_orders = [];

    if ( my $orders = $req->param('order') ) {
        for my$order_param( split(/,/, $orders) ) {
            next unless $order_param =~ m/^(-)?(.+)$/;

            my $order = defined($1) ? $1 : '';
            
            push $attr_orders, ($order eq '-') ? "$2 DESC" : "$2 ASC";
        }
    }

    my $newer = $req->param('newer');
    my $older = $req->param('older');

    if ( $newer ) {
        $attr->{ limit } = $newer;
        delete $attr->{ offset };
        if ( ref $where->{ id } ) {
            $where->{ id } = $where->{ id }->[0];
            $where->{ id } = { '>' => $where->{ id } };
            push $attr_orders, 'id DESC';
        }
        elsif ( ref $where->{ created_at_ms } ) {
            $where->{ created_at_ms } = { '>' => $where->{ created_at_ms }->[0] };
            push $attr_orders, 'created_at_ms DESC';
        }
    }
    elsif ( $older ) {
        $attr->{ limit } = $older;
        delete $attr->{ offset };
        if ( ref $where->{ id } ) {
            $where->{ id } = $where->{ id }->[0];
            $where->{ id } = { '<' => $where->{ id } };
            push $attr_orders, 'id DESC';
        }
        elsif ( ref $where->{ created_at_ms } ) {
            $where->{ created_at_ms } = { '<' => $where->{ created_at_ms }->[0] };
            push $attr_orders, 'created_at_ms DESC';
        }
    }

    $attr->{ order_by } = $attr_orders;
    $attr->{ limit } ||= 20;

    return $self->sys->data_storage->search_post( $where, $attr );
}


1;
