package Yancha::DataStorage::DBI::SQLite;
use strict;
use warnings;
use base 'Yancha::DataStorage::DBI';

our $VERSION = '0.01';

sub time_literal {
    my ($self, $time) = @_;
    $time; # insert epoch seconds in DB
}

1;

__END__
