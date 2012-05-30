package Yairc::Plugin::WelcomeMessage;

use strict;
use warnings;
use utf8;
use JSON ();

my $USER = {};

sub setup {
    my ( $class, $sys, %opt ) = @_;
    my $nickname          = $opt{ nickname } || 'system';
    my $user_key          = $opt{ user_key } || '*:system';
    my $profile_image_url = $opt{ profile_image_url } || '';
    my $message           = $opt{ message } || 'Welcom, %s!!';

    $sys->register_hook( 'after_sent_log', sub {
        my ( $sys, $socket ) = @_;
        my $user;

        $socket->get('user_data', sub {
            $user = $_[2];
        });

        return if ( !$user or exists $USER->{ $user->{ token } } );

        $USER->{ $user->{ token } } = time;

        my $tags = $sys->tags_reverse->{ $socket->id } || ['PUBLIC'];# TODO: default tag使う
        my $welcome = {
            id       => '-1',
            text     => sprintf( $message, $user->{ nickname } ),
            nickname => $nickname,
            user_key => $user_key,
            tags     => $tags,
            created_at_ms     => $sys->data_storage->_get_now_micro_sec,
            is_message_log    => JSON::false,
            profile_image_url => $profile_image_url,
        };
        $socket->emit( 'user message', $welcome );
    } );

    $sys->register_hook( 'disconnected', sub {
        my ( $sys, $socket, $user ) = @_;

        return unless $user and exists $USER->{ $user->{ token } };

        # 短い時間なら削除しないで延長
        if ( time < $USER->{ $user->{ token } } + 3600 ) {
            $USER->{ $user->{ token } } = time;
            return;
        }

        delete $USER->{ $user->{ token } };
    } );
}

1;

