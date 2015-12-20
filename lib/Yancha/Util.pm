package Yancha::Util;

use strict;
use warnings;
use Exporter qw/ import /;
our @EXPORT_OK = qw/load_module load_plugins/;

sub load_module {
    my ( $self, $type, $module ) = @_;

    if ( @_ == 2 ) {
        $module = $type;
        $module = '+' . $module if $module !~ /^\+/;
    }

    if ( $module !~ s/^\+// ) {
        $module = ref($self) . '::' . $type . '::' . $module;
    }

    eval {
        ( my $path = $module . '.pm' ) =~ s{::}{/}g;
        require $path;
        $path->import();
    };
    if ( $@ ) {
        Carp::croak $@;
    }

    return $module;
}

sub load_plugins {
    my ( $self, $plugins ) = @_;
    return unless $plugins and ref($plugins) eq 'ARRAY';

    for my $plugin_and_args ( @{ $plugins } ) {
        my ( $plugin, $args ) = @{ $plugin_and_args };
        eval { ( my $path = $plugin . '.pm' ) =~ s{::}{/}g; require $path };
        if ( $@ ) {
            Carp::carp $@;
            next;
        }
        $plugin->setup( $self, @$args );
    }
}

sub is_smartphone {
    my ( $self, $ua ) = @_;
    return ($ua =~ m/(iPod|iPhone|iPad|Android|PlayStation Vita|Windows Phone)/);
}

1;
