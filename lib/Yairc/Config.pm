package Yairc::Config;

use strict;
use warnings;
use Carp ();

my %SOCKETIO_TABLE = (
    'heartbeat_interval' => 'heartbeat_timeout',
    'handshake_timeout'  => 'connect_timeout',
);


sub load_file {
    my ( $class, $filename ) = @_;

    $filename ||= './config.pl';

    Carp::croak("Can't found $filename.") unless -s $filename;

    my $config = do $filename;

    if ( $@ ) { Carp::croak( $! ) }

    unless ( defined $config && ref($config) eq 'HASH' ) {
        Carp::croak("$filename must return hash reference.");
    }

    # PocketIOの紛らわしい設定名のために変換
    my $socketio = $config->{ socketio };

    return $config unless $socketio;

    while ( my ($alias, $realname) = each %SOCKETIO_TABLE ) {
        next unless exists $socketio->{ $alias };
        Carp::carp( "$alias and $realname are set at same time." ) if $socketio->{ $realname };
        $socketio->{ $realname } = delete $socketio->{ $alias };
    }

    return $config;
}


1;
__END__

