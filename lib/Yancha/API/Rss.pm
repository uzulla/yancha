package Yancha::API::Rss;

use strict;
use warnings;
use utf8;
use Yancha::API;
use parent qw(Yancha::API);
use XML::Feed;
use DateTime;
use POSIX qw(floor);

use Data::Dumper;

our $VERSION = '0.01';

sub run {
    my ( $self, $req ) = @_;
    my $server_info = $self->sys->config->{server_info};
    my $posts = _get_recent_posts($self, $req);

    my $last_update_dt = _get_datetime_from_ms($posts->[0]->{created_at_ms});

    my $feed = XML::Feed->new('Atom', encode_output => 0);
    $feed->id($server_info->{url});
    $feed->title("yancha::".$server_info->{name});
    $feed->link($server_info->{url});
    $feed->modified($last_update_dt);
	
	foreach my $post ( @$posts) {
		my $entry = XML::Feed::Entry->new();
		my $url = $server_info->{url}."quotation.html?id=".$post->{id};
		$entry->id($url);
		my $title = my $content = $post->{nickname}." : ".$post->{text};
		$title =~ s/[\r\n]//g;
		$title = substr ($title, 0, 64);
		$entry->link($url);
		$entry->title($title);
		$entry->content($content);
		$entry->modified(_get_datetime_from_ms($post->{created_at_ms}));
		$feed->add_entry($entry);
	}

    my $res = Plack::Response->new(200);

    $res->content_type( "application/rss+xml; charset=utf-8" );
    $res->body( $feed->as_xml );

    return $res;
}

sub _get_recent_posts {
    my ( $self, $req ) = @_;
    my $where = {};
    my $attr  = {};

    $attr->{ limit } = 20;

    return $self->sys->data_storage->search_post( $where, $attr );
}

sub _get_datetime_from_ms {
    my $millisec = shift;
    return DateTime->from_epoch( epoch=>floor($millisec/100_000) );
}

1;
