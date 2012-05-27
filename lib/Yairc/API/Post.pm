package Yairc::API::Post;

use strict;
use warnings;
use utf8;
use Encode;
use parent qw(Yairc::API);
use Yairc::DataStorage;

sub run {
    my ( $self, $req ) = @_;

    my $user = {};
    if ( my $token = $req->param('token') ) {
        $user = $self->sys->data_storage->get_user_by_token( { token => $token } );
    }

    unless ( $user ) {
        return $self->response({}, 401);
    }

    my $text = '';
    unless ( $text = encode('utf8', $req->param('text')) ) {
        return $self->response({}, 400);
    }

    my $tags = [];
    unless ( $tags = [ $self->sys->extract_tags_from_text( $text ) ] ) {
        $tags = ['PUBLIC'];
    }

    my $post = {
        text => $text,
        tags => $tags,
    };

    unless ( $post = $self->sys->data_storage->add_post( $post, $user ) ) {
        return $self->response({}, 400);
    }

    $self->sys->send_post_to_tag_joined( $post, $tags );

    return $self->response({}, 200);
}

1;
