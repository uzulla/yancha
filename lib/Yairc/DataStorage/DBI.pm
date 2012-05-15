package Yairc::DataStorage::DBI;

use strict;
use warnings;
use base 'Yairc::DataStorage';
use DBI;
use SQL::Maker;
use Carp ();

our $VERSION = '0.01';


sub dbh { $_[0]->{ dbh }; }

sub connect {
    my $class = shift;
    my %args = @_;
    my $connect_info = $args{ connect_info };

    Carp::croak("Not connect_info.") unless $connect_info;

    my $name = $class->_extract_dbd( $connect_info->[0] );

    Carp::croak("dsn does not contain DBD type.") unless $name;

    $class = $class . "::$name";
    eval qq{ use $class; };
    Carp::croak( $@ ) if ( $@ );

    my $dbh  = DBI->connect( @$connect_info ) or Carp::croak(DBI::errstr);
    my $self = $class->new( dbh => $dbh );

    return $self;
}

sub _extract_dbd {
    my ( $class, $dsn ) = @_;
    my ( $name ) = $dsn =~ /dbi:(\w+)/i;
    return $name;
}

1;
__END__

