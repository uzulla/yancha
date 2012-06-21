package Yancha::DataStorage::DBI::mysql;

use strict;
use warnings;
use base 'Yancha::DataStorage::DBI';

our $VERSION = '0.01';

sub add_or_replace_user {
    my ( $self, $user, $extra ) = @_;
    my $sth = $self->dbh->prepare(q/
        INSERT INTO `user` (
            `user_key`,`nickname`,`profile_image_url`,
            `sns_data_cache`,`created_at`,`updated_at`
        ) VALUES ( ?, ?, ?, ?, now(), now() )
        ON DUPLICATE KEY UPDATE `sns_data_cache`=values(`sns_data_cache`),
        `nickname`=values(`nickname`),
        `profile_image_url`=values(`profile_image_url`),
        `updated_at`=now();
    /); # / .. for poor editor syntax hilight

    $sth->execute( @{$user}{qw/user_key nickname profile_image_url sns_data_cache/} );
    my $_user = $self->get_user_by_userkey( $user->{ user_key } );
    $self->add_session( $user->{user_key}, $user->{token}, $extra );
    $_user->{token} = $user->{token};
    return $_user;
}

1;
__END__

