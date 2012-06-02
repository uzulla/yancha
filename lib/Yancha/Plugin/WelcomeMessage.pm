package Yancha::Plugin::WelcomeMessage;

use strict;
use warnings;
use utf8;
use JSON ();

my $USER = {};

sub setup {
    my ( $class, $sys, %opt ) = @_;
    my $message      = $opt{ message } || 'Welcome, %s!!';
    my $welcome_code = $message;

    unless ( ref $welcome_code eq 'CODE' ) {
        $welcome_code = sub {
            my ( $socket, $user ) = @_;
            sprintf( $message, $user->{ nickname } );
        };
    }

    $sys->register_hook( 'after_sent_log', sub {
        my ( $sys, $socket ) = @_;
        my $user;

        $socket->get('user_data', sub {
            $user = $_[2];
        });

        return if ( !$user or exists $USER->{ $user->{ token } } );

        $USER->{ $user->{ token } } = time;

        my $message = $welcome_code->( $socket, $user );

        $socket->emit( 'announcement', $message );
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

