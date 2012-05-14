package Yairc::Plugin::DenyDoubleSimpleLogin;

use strict;
use warnings;

my $USERS = {};

sub setup {
    my ( $class, $sys, %opt ) = @_;
    my ( $mark, $target_sns_keys ) = ($opt{mark}, $opt{sns_key});
    my %target_sns_key = map { $_ => 1 } @{ $target_sns_keys || ['-'] };

    $mark ||= '_';

    $sys->register_hook( 'authenticated', sub {
        my ( $sys, undef, $user ) = @_;
        my ($sns_key, $user_id) = split /:/, $user->{ user_key };

        return unless exists $target_sns_key{ $sns_key };

        SEARCH: {
            my @users = values $USERS;
            for my $connected_user ( @users ) {
                next unless $connected_user->{ user_key } eq $user->{ user_key };
                $user->{ nickname } .= $mark;
                $user_id .= $mark;
                $user->{ user_key } = $sns_key . ':' . $user_id;
                redo SEARCH;
            }
        }

        $USERS->{ $user->{ user_key } } = $user;
    } );

}


1;

