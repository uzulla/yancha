package Yancha::Plugin::NoRec;

# user messageのpostを記録しないタグ'norec'を提供

use strict;
use warnings;

sub setup {
    my ( $class, $sys ) = @_;

    $sys->register_calling_tag('norec', sub {
        my ( $sys, $socket, $tag, $tags, $message_ref, $ctx ) = @_;
        $ctx->{ norec } = 1;
    });

    $sys->register_hook( 'before_send_post', sub {
        my ( $sys, $socket, $post, $ctx ) = @_;
        return unless $ctx->{ norec };
        $ctx->{ record_post } = 0;
        $post->{ id } = -2;
        $post->{ text } = '[NoRec] ' . $post->{ text };
    } );

}

1;

