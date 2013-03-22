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
    
    my $posts = _get_recent_posts($self, $req);
    #Carp::croak(Dumper($posts));
    #Carp::croak( $posts->[0]->{created_at_ms} );

    my $last_update_dt = _get_datetime_from_ms($posts->[0]->{created_at_ms});
    #Carp::croak($last_update_dt->iso8601());

    my $feed = XML::Feed->new('RSS', version=>'1.0', encode_output => 0);
	#$feed->id("http://".time.rand()."/");
	$feed->title("yancha::".$self->sys->config->{server_info}->{name});
	$feed->link("http://yancha.hachiojipm.org:3000/");
	$feed->modified($last_update_dt);
	
	foreach my $post ( @$posts ){
		my $entry = XML::Feed::Entry->new();
		#$entry->id("http://".time.rand()."/");
		$entry->link("http://yancha.hachiojipm.org:3000/");
		$entry->title($post->{nickname}." : ".$post->{text});
		$entry->content($post->{nickname}." : ".$post->{text});
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
