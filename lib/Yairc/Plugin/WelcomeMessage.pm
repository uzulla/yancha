package Yairc::Plugin::WelcomeMessage;

use strict;
use warnings;
use utf8;
use JSON ();

sub setup {
    my ( $class, $sys, %opt ) = @_;
    my $tags              = $opt{ tags } || ['PUBLIC'];
    my $nickname          = $opt{ nickname } || 'system';
    my $user_key          = $opt{ user_key } || '-:system';
    my $created_at_ms     = $opt{ created_at_ms } || 0;
    my $profile_image_url = $opt{ profile_image_url } || '';
    my $message           = $opt{ message } || 'Welcom, %s!!';

    @$tags = map { uc($_) } @$tags;

    $sys->register_hook( 'token_logined', sub {
        my ( $sys, $socket, $user ) = @_;
        my $welcome = {
            id       => '-1',
            text     => sprintf( $message, $user->{ nickname } ),
            nickname => $nickname,
            user_key => $user_key,
            tags     => $tags,
            created_at_ms     => $created_at_ms,
            is_message_log    => JSON::false,
            profile_image_url => $profile_image_url,
        };
        $socket->emit( 'user message', $welcome );
    } );

}

1;

