package Yancha::API::Search;

use strict;
use warnings;
use utf8;
use Yancha::API;
use parent qw(Yancha::API);
use Encode ();
use XML::FeedPP;
use POSIX qw(floor);

our $VERSION = '0.01';


sub run {
    my ( $self, $req, $opt ) = @_;
    my $posts  = $self->_search_posts( $req );

    my $format;
    if ( defined $opt->{format} ) {
        $format = $opt->{format};
    }
    else {
        $format = $req->param('t') || 'json';
    }

    if ( $format eq 'text' ) {
        return $self->response_as_text( ref $posts eq 'ARRAY' ? $posts : [ $posts ] );
    }
    elsif ( $format eq 'rss' ) {
        return $self->response( $self->_rss_feed( $posts ), 200, "application/rss+xml; charset=utf-8" );
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
            
            push @{$attr_orders}, ($order eq '-') ? "$2 DESC" : "$2 ASC";
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
            push @{$attr_orders}, 'id DESC';
        }
        elsif ( ref $where->{ created_at_ms } ) {
            $where->{ created_at_ms } = { '>' => $where->{ created_at_ms }->[0] };
            push @{$attr_orders}, 'created_at_ms DESC';
        }
    }
    elsif ( $older ) {
        $attr->{ limit } = $older;
        delete $attr->{ offset };
        if ( ref $where->{ id } ) {
            $where->{ id } = $where->{ id }->[0];
            $where->{ id } = { '<' => $where->{ id } };
            push @{$attr_orders}, 'id DESC';
        }
        elsif ( ref $where->{ created_at_ms } ) {
            $where->{ created_at_ms } = { '<' => $where->{ created_at_ms }->[0] };
            push @{$attr_orders}, 'created_at_ms DESC';
        }
    }

    $attr->{ order_by } = $attr_orders;
    $attr->{ limit } ||= 20;

    return $self->sys->data_storage->search_post( $where, $attr );
}

sub _rss_feed {
    my ($self, $posts) = @_;

    my $server_info = $self->sys->config->{server_info};

    my $last_update_dt = _get_datetime_from_ms($posts->[0]->{created_at_ms});
    my $server_url = $server_info->{url} || '';

    my $feed = XML::FeedPP::Atom->new();
    $feed->title("yancha::".$server_info->{name});
    $feed->link($server_info->{url});
    $feed->pubDate($last_update_dt);

	foreach my $post ( @$posts) {
		my $url   = $server_url . "quot/" . $post->{id};
		my $entry = $feed->add_item($url);
		my $title = my $content = $post->{nickname}." : ".$post->{text};
		$entry->guid($url);
		$title =~ s/[\r\n]//g;
		$title = substr ($title, 0, 64);
		$entry->link($url);
		$entry->title($title);
		$entry->description($content);
		$entry->pubDate(_get_datetime_from_ms($post->{created_at_ms}));
	}

    return $feed->to_string;
}

sub _get_datetime_from_ms {
    return floor($_[0] / 100_000);
}

1;
