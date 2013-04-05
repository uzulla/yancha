package Yancha::API::Post;

use strict;
use warnings;
use utf8;
use Encode;
use parent qw(Yancha::API);
use Yancha::DataStorage;

sub run {
    my ( $self, $req ) = @_;
    my $data_storage = $self->sys->data_storage;

    my $token = $req->param('token');
    $self->response({}, 401) unless $token;

    my $user = $data_storage->get_user_by_token({ token => $token }) || {};
    $self->response({}, 401) unless keys %$user;

    my $text = decode_utf8 $req->param('text') || '';
    return $self->response({}, 400) unless $text;

    my @tags = $self->sys->extract_tags_from_text( $text );
    unless (@tags) {
        @tags = qw(PUBLIC);
    }

    my $post = $data_storage->make_post({
        text => $text,
        tags => \@tags,
        user => $user,
    });
    return $self->response({}, 400) unless $post;

    $data_storage->add_post($post);

    $self->sys->send_post_to_tag_joined( $post, \@tags );

    return $self->response({}, 200);
}

1;
