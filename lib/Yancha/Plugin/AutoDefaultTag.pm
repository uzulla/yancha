package Yancha::Plugin::AutoDefaultTag;

use strict;
use warnings;

sub setup {
    my ( $class, $sys, $tag ) = @_;

    $tag = uc($tag);

    $sys->register_calling_tag( undef, sub {
        my ( $sys, $socket, undef, $message_ref, $tags ) = @_;
        $$message_ref = $$message_ref . ' #' . $tag;
        push @$tags, $tag;
    } );
}


1;

